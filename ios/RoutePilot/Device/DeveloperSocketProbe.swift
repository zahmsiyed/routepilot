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

private final class Probe: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "routepilot.socket-probe", qos: .utility)
    private let lock = NSLock()
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<Void, Error>?
    private var finished: Result<Void, Error>?
    private var deadline: DispatchWorkItem?

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
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready: self?.finish(.success(()))
                case .failed(let error):
                    if case .posix(let code) = error, code == .EACCES || code == .EPERM {
                        self?.finish(.failure(DeviceError(.localNetwork, "iOS denied local network access.")))
                    } else { self?.finish(.failure(error)) }
                case .waiting(let error):
                    if case .posix(let code) = error, code == .EACCES || code == .EPERM { self?.finish(.failure(DeviceError(.localNetwork, "iOS denied local network access."))) }
                default: break
                }
            }
            let deadline = DispatchWorkItem { [weak self] in
                self?.finish(.failure(DeviceError(.localTunnel, "No TCP response from the local developer service before the connection deadline.")))
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
