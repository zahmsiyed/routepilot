// Address matching is adapted from LocSim 359e423824d8c236a343c871ba696ba08fd3bec1 (MIT).
// Copyright (c) 2026 rockykln. See ios/Vendor/LocSim-LICENSE.txt.
import Darwin
import Foundation

struct LocalPairingService: Equatable, Sendable {
    let port: UInt16
    let isThisDevice: Bool
}

struct PairingDiscoveryResult: Equatable, Sendable {
    var services: [LocalPairingService] = []
    var searchFailed = false
}

/// Browse only while the user connects. Never treat another phone's advertisement
/// as this device: compare resolved IPs with this device's current interfaces.
/// The pairing file's `identifier` is the host identity, not a Bonjour device ID.
@MainActor
final class LocalPairingDiscovery: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    private var browser: NetServiceBrowser?
    private var resolving: [NetService] = []
    private var result = PairingDiscoveryResult()
    private var continuation: CheckedContinuation<PairingDiscoveryResult, Error>?
    private var timeout: Task<Void, Never>?

    func browse(timeout seconds: TimeInterval = 4) async throws -> PairingDiscoveryResult {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                let browser = NetServiceBrowser()
                browser.delegate = self
                self.browser = browser
                browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(max(0.1, min(seconds, 5)))) } catch { return }
                    self?.finish()
                }
            }
        }, onCancel: { Task { @MainActor [weak self] in self?.finish(cancelled: true) } })
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        result.searchFailed = true
        finish()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard continuation != nil, resolving.count < 20 else { return }
        resolving.append(service)
        service.delegate = self
        service.resolve(withTimeout: 2)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard continuation != nil, let port = UInt16(exactly: sender.port), port > 0 else { return }
        let local = Self.interfaceAddresses()
        let own = (sender.addresses ?? []).compactMap(Self.address).contains { local.contains($0) }
        let service = LocalPairingService(port: port, isThisDevice: own)
        if !result.services.contains(service) { result.services.append(service) }
    }

    private func finish(cancelled: Bool = false) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel(); timeout = nil
        browser?.stop(); browser?.delegate = nil; browser = nil
        resolving.forEach { $0.stop(); $0.delegate = nil }; resolving = []
        if cancelled { continuation.resume(throwing: CancellationError()) }
        else { continuation.resume(returning: result) }
    }

    private static func address(_ data: Data) -> String? {
        data.withUnsafeBytes { raw in
            guard let address = raw.baseAddress?.assumingMemoryBound(to: sockaddr.self) else { return nil }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(data.count), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
            return normalize(String(cString: host))
        }
    }

    private static func normalize(_ ip: String) -> String {
        String(ip.split(separator: "%").first ?? "").lowercased()
    }

    static func interfaceAddresses() -> Set<String> {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return [] }
        defer { freeifaddrs(head) }
        var found = Set<String>()
        var cursor = head
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            guard let address = item.pointee.ifa_addr else { continue }
            let family = Int32(address.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            let length = family == AF_INET ? MemoryLayout<sockaddr_in>.size : MemoryLayout<sockaddr_in6>.size
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(length), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                found.insert(normalize(String(cString: host)))
            }
        }
        return found
    }
}
