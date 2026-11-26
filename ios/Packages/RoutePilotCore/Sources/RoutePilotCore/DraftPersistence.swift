import Foundation

/// Encodes and writes on this actor's executor, away from the main actor.
/// Monotonic generations make asynchronously delivered snapshots safe even
/// when an older scheduling task arrives after a newer flush.
public actor DraftPersistence<Snapshot: Encodable & Sendable> {
    public typealias FailureHandler = @Sendable (_ message: String) -> Void
    public typealias Writer = @Sendable (_ data: Data, _ destination: URL) throws -> Void
    private let destination: URL
    private let debounce: Duration
    private let maximumBytes: Int
    private let writer: Writer
    private var generation: UInt64 = 0
    private var writtenGeneration: UInt64 = 0
    private var latest: Snapshot?
    private var onFailure: FailureHandler?
    private var pending: Task<Void, Never>?

    public init(destination: URL, debounce: Duration = .milliseconds(250), maximumBytes: Int = 4_000_000, writer: Writer? = nil) {
        self.destination = destination
        self.debounce = debounce
        self.maximumBytes = maximumBytes
        self.writer = writer ?? { data, destination in
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            #if os(iOS)
            try data.write(to: destination, options: [.atomic, .completeFileProtectionUnlessOpen])
            #else
            try data.write(to: destination, options: .atomic)
            #endif
        }
    }

    @discardableResult public func schedule(_ snapshot: Snapshot, generation newGeneration: UInt64, onFailure: FailureHandler? = nil) -> Bool {
        guard accept(snapshot, generation: newGeneration, onFailure: onFailure) else { return false }
        pending?.cancel()
        let expected = generation
        let delay = debounce
        pending = Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { return }
            await self?.writeIfCurrent(expected)
        }
        return true
    }

    /// Accepts the latest main-actor snapshot before flushing, so a queued older
    /// schedule cannot overwrite the state saved when the app was backgrounded.
    @discardableResult public func flush(_ snapshot: Snapshot, generation newGeneration: UInt64) throws -> Bool {
        _ = accept(snapshot, generation: newGeneration, onFailure: onFailure)
        return try flush()
    }

    @discardableResult public func flush() throws -> Bool {
        pending?.cancel()
        pending = nil
        return try writeLatest()
    }

    private func accept(_ snapshot: Snapshot, generation newGeneration: UInt64, onFailure handler: FailureHandler?) -> Bool {
        guard newGeneration > generation else { return false }
        generation = newGeneration
        latest = snapshot
        onFailure = handler
        return true
    }

    private func writeIfCurrent(_ expected: UInt64) {
        guard expected == generation else { return }
        pending = nil
        do { _ = try writeLatest() } catch { onFailure?(error.localizedDescription) }
    }

    private func writeLatest() throws -> Bool {
        guard let snapshot = latest, generation > writtenGeneration else { return false }
        let encoded = try JSONEncoder().encode(snapshot)
        guard encoded.count <= maximumBytes else { throw RoutePilotError("The route draft is too large to save. Use a shorter route.") }
        try writer(encoded, destination)
        writtenGeneration = generation
        return true
    }
}
