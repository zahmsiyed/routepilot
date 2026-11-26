// ResumeGate is adapted from LocSim 359e423824d8c236a343c871ba696ba08fd3bec1 (MIT).
// Copyright (c) 2026 rockykln. See ios/Vendor/LocSim-LICENSE.txt.
import Foundation

final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    private var began = false

    var didBegin: Bool { lock.withLock { began } }

    /// False if the deadline passed before the call could start.
    func begin() -> Bool {
        lock.withLock {
            began = !done
            return began
        }
    }

    func claim() -> Bool {
        lock.withLock {
            defer { done = true }
            return !done
        }
    }
}

/// Cancellation resumes the Swift caller, but never pretends to cancel a native
/// command already running. The transport remains quarantined until it settles.
final class NativeOperationCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var handler: (() -> Void)?
    func install(_ handler: @escaping () -> Void) {
        let fire = lock.withLock { () -> Bool in self.handler = handler; return cancelled }
        if fire { handler() }
    }
    func cancel() {
        let callback = lock.withLock { () -> (() -> Void)? in
            guard !cancelled else { return nil }
            cancelled = true
            return handler
        }
        callback?()
    }
    func clear() { lock.withLock { handler = nil } }
}
