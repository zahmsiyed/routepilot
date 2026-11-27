import Foundation
import Network

/// TCP reachability only: no pairing request, DDI mutation, or GPS command.
/// A closed/blocked socket fails before starting the much slower FFI handshake.
enum DeveloperSocketProbe {
    static func check(host: String, port: UInt16, timeout: TimeInterval = 2) async throws {
        guard port > 0 else { throw DeviceError(.localTunnel, "Choose a valid TCP port.") }
        let probe = Probe(host: host, port: port, timeout: timeout)
        try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            try await probe.run()
        }, onCancel: { probe.cancel() })
    }
}

/// Keep only categorical state and numeric error codes. NWPath descriptions and
/// interface objects can contain endpoint or network identifiers.
struct SocketProbeDiagnostics {
    var state = "setup"
    private(set) var lastWaitingError: String?
    private(set) var pathStatus: String?
    private(set) var pathReason: NWPath.UnsatisfiedReason?

    mutating func waiting(_ error: NWError) {
        state = "waiting"
        lastWaitingError = Self.errorCode(error)
    }

    mutating func record(_ path: NWPath?) {
        guard let path else { return }
        recordPath(status: path.status, reason: path.status == .satisfied ? nil : path.unsatisfiedReason)
    }

    mutating func recordPath(status: NWPath.Status, reason: NWPath.UnsatisfiedReason?) {
        switch status {
        case .satisfied: pathStatus = "satisfied"
        case .unsatisfied: pathStatus = "unsatisfied"
        case .requiresConnection: pathStatus = "requires-connection"
        @unknown default: pathStatus = "unknown"
        }
        pathReason = reason
    }

    var timeoutError: DeviceError {
        var details = ["last state: \(state)"]
        if let lastWaitingError { details.append("last waiting error: \(lastWaitingError)") }
        if let pathStatus {
            details.append("last path: \(pathStatus)\(pathReason.map { "/" + Self.reasonName($0) } ?? "")")
        } else { details.append("last path: unavailable") }
        return DeviceError(.localTunnel, "No TCP response from the local developer service before the connection deadline (\(details.joined(separator: "; "))).")
    }

    // Apple TN3179 documents waiting + currentPath.localNetworkDenied, and
    // kDNSServiceErr_PolicyDenied (-65570) for network privacy denial.
    // https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
    static func permissionError(_ error: NWError? = nil, reason: NWPath.UnsatisfiedReason? = nil) -> DeviceError? {
        if reason == .localNetworkDenied {
            return DeviceError(.localNetwork, "Local network access was denied (path: local-network-denied).")
        }
        switch error {
        case .posix(let code) where code == .EACCES || code == .EPERM:
            return DeviceError(.localNetwork, "Local network access was denied (POSIX \(code.rawValue)).", code: code.rawValue)
        case .dns(let code) where code == -65570:
            return DeviceError(.localNetwork, "Local network access was denied (DNS PolicyDenied -65570).", code: code)
        default: return nil
        }
    }

    private static func errorCode(_ error: NWError) -> String {
        switch error {
        case .posix(let code): return "POSIX \(code.rawValue)"
        case .dns(let code): return "DNS \(code)"
        case .tls(let code): return "TLS \(code)"
        default: return "unclassified network error"
        }
    }

    private static func reasonName(_ reason: NWPath.UnsatisfiedReason) -> String {
        if #available(iOS 17.0, macOS 14.0, *), reason == .vpnInactive { return "vpn-inactive" }
        switch reason {
        case .notAvailable: return "not-available"
        case .cellularDenied: return "cellular-denied"
        case .wifiDenied: return "wifi-denied"
        case .localNetworkDenied: return "local-network-denied"
        default: return "unknown"
        }
    }
}

private final class Probe: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "routepilot.socket-probe", qos: .utility)
    private let lock = NSLock()
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<Void, Error>?
    private var finished: Result<Void, Error>?
    private var deadline: DispatchWorkItem?
    // NWConnection's state/path callbacks and the deadline run on this queue.
    private var diagnostics = SocketProbeDiagnostics()

    init(host: String, port: UInt16, timeout: TimeInterval) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        self.timeout = max(0.1, min(timeout, 3))
    }

    func run() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let early = lock.withLock { () -> Result<Void, Error>? in
                if let finished { return finished }
                self.continuation = continuation
                return nil
            }
            if let early { continuation.resume(with: early); return }
            connection.stateUpdateHandler = { [weak self] in self?.stateChanged($0) }
            connection.pathUpdateHandler = { [weak self] in self?.pathChanged($0) }
            let deadline = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.diagnostics.record(self.connection.currentPath)
                if let error = SocketProbeDiagnostics.permissionError(reason: self.diagnostics.pathReason) {
                    self.finish(.failure(error))
                } else { self.finish(.failure(self.diagnostics.timeoutError)) }
            }
            let shouldStart = lock.withLock { () -> Bool in
                guard finished == nil else { return false }
                self.deadline = deadline
                return true
            }
            guard shouldStart else { return }
            queue.asyncAfter(deadline: .now() + timeout, execute: deadline)
            connection.start(queue: queue)
        }
    }

    func cancel() { finish(.failure(CancellationError())) }

    private func stateChanged(_ state: NWConnection.State) {
        diagnostics.record(connection.currentPath)
        switch state {
        case .setup: diagnostics.state = "setup"
        case .preparing: diagnostics.state = "preparing"
        case .ready: finish(.success(()))
        case .waiting(let error):
            diagnostics.waiting(error)
            if let denied = SocketProbeDiagnostics.permissionError(error, reason: diagnostics.pathReason) { finish(.failure(denied)) }
        case .failed(let error):
            diagnostics.state = "failed"
            finish(.failure(SocketProbeDiagnostics.permissionError(error, reason: diagnostics.pathReason) ?? error))
        case .cancelled: diagnostics.state = "cancelled"
        @unknown default: diagnostics.state = "unknown"
        }
    }

    private func pathChanged(_ path: NWPath) {
        diagnostics.record(path)
        // Path and state notifications can arrive separately. Catch a denial
        // that appears after the connection first reports waiting.
        if diagnostics.state == "waiting", let denied = SocketProbeDiagnostics.permissionError(reason: diagnostics.pathReason) { finish(.failure(denied)) }
    }

    private func finish(_ result: Result<Void, Error>) {
        let completion = lock.withLock { () -> (CheckedContinuation<Void, Error>?, DispatchWorkItem?) in
            guard finished == nil else { return (nil, nil) }
            finished = result
            defer { self.continuation = nil; self.deadline = nil }
            return (self.continuation, self.deadline)
        }
        completion.1?.cancel()
        connection.cancel()
        completion.0?.resume(with: result)
    }
}
