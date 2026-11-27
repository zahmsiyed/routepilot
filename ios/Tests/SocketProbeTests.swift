import Darwin
import Foundation
import Network

/// The only live sockets in this harness are bound to 127.0.0.1. Permission
/// classifications are injected enum values, not changes to system settings.
private final class LoopbackSocket {
    let descriptor: Int32
    let port: UInt16

    init(listening: Bool) throws {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        var keep = false
        defer { if !keep { Darwin.close(socket) } }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socket, $0, &length) }
        }
        guard named == 0, !listening || Darwin.listen(socket, 128) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno)!) }
        descriptor = socket
        port = UInt16(bigEndian: address.sin_port)
        keep = true
    }

    deinit { Darwin.close(descriptor) }

    func drain() {
        _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)
        while true {
            let accepted = accept(descriptor, nil, nil)
            if accepted < 0 { return }
            Darwin.close(accepted)
        }
    }
}

@main struct SocketProbeTests {
    @MainActor static func main() async throws {
        var scenarios = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw NSError(domain: "SocketProbeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        for error in [NWError.posix(.EACCES), .posix(.EPERM)] {
            try check(SocketProbeDiagnostics.permissionError(error)?.kind == .localNetwork, "POSIX permission denials must be classified")
        }
        scenarios += 1
        try check(SocketProbeDiagnostics.permissionError(.dns(-65570))?.kind == .localNetwork, "DNS PolicyDenied must be classified")
        scenarios += 1
        try check(SocketProbeDiagnostics.permissionError(.posix(.ENETDOWN), reason: .localNetworkDenied)?.kind == .localNetwork, "Path privacy denial must take precedence over a generic waiting error")
        scenarios += 1
        try check(SocketProbeDiagnostics.permissionError(.posix(.ECONNREFUSED)) == nil && SocketProbeDiagnostics.permissionError(.dns(-65563)) == nil, "Refusal and unrelated DNS errors are not privacy denials")
        scenarios += 1
        var diagnostics = SocketProbeDiagnostics()
        diagnostics.waiting(.posix(.ENETDOWN))
        diagnostics.recordPath(status: .unsatisfied, reason: .notAvailable)
        try check(diagnostics.timeoutError.kind == .localTunnel && diagnostics.timeoutError.message.contains("last state: waiting") && diagnostics.timeoutError.message.contains("POSIX 50") && diagnostics.timeoutError.message.contains("unsatisfied/not-available"), "Timeout retains only useful categorical waiting/path context")
        try check(!diagnostics.timeoutError.message.contains("127.0.0.1") && !diagnostics.timeoutError.message.contains("en0"), "Timeout does not contain endpoint or interface identifiers")
        scenarios += 1
        if #available(macOS 14.0, *) {
            diagnostics.recordPath(status: .requiresConnection, reason: .vpnInactive)
            try check(diagnostics.timeoutError.message.contains("requires-connection/vpn-inactive"), "Inactive VPN path context remains distinct")
            try check(SocketProbeDiagnostics.permissionError(reason: .vpnInactive) == nil, "An inactive VPN is not a privacy denial")
            scenarios += 1
        }
        let listener = try LoopbackSocket(listening: true)
        try await DeveloperSocketProbe.check(host: "127.0.0.1", port: listener.port, timeout: 0.5)
        listener.drain()
        scenarios += 1
        let reserved = try LoopbackSocket(listening: false)
        let began = ContinuousClock.now
        var failed = false
        do {
            try await DeveloperSocketProbe.check(host: "127.0.0.1", port: reserved.port, timeout: 0.25)
        } catch {
            failed = true
            try check((error as? DeviceError)?.kind != .localNetwork, "Loopback refusal must not be called a privacy denial")
            try check(began.duration(to: .now) < .seconds(2), "Refusal or waiting must finish before its bounded deadline")
        }
        try check(failed, "A non-listening socket must not connect")
        scenarios += 1
        let cancelled = Task { try await DeveloperSocketProbe.check(host: "127.0.0.1", port: listener.port, timeout: 1) }
        cancelled.cancel()
        do { try await cancelled.value; throw NSError(domain: "SocketProbeTests", code: 3) }
        catch is CancellationError { }
        scenarios += 1
        for _ in 0..<30 {
            let task = Task { try await DeveloperSocketProbe.check(host: "127.0.0.1", port: listener.port, timeout: 0.5) }
            await Task.yield()
            task.cancel()
            do { try await task.value } catch is CancellationError { }
            listener.drain()
        }
        scenarios += 1
        print("Socket probe: \(scenarios) scenarios passed (loopback TCP only; no device, VPN, or external networking).")
    }
}
