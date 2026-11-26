import XCTest
@testable import RoutePilotCore

@MainActor final class DraftPersistenceTests: XCTestCase {
    func testOutOfOrderSnapshotCannotOverwriteNewerFlushAndWriterRunsOffMain() async throws {
        let recorder = PersistenceRecorder()
        let persistence = DraftPersistence<Snapshot>(destination: URL(fileURLWithPath: "/unused/draft.json"), debounce: .seconds(60), writer: { @Sendable data, destination in try recorder.write(data, destination) })
        _ = await persistence.schedule(Snapshot(value: 2), generation: 2)
        let acceptedOld = await persistence.schedule(Snapshot(value: 1), generation: 1)
        XCTAssertFalse(acceptedOld)
        _ = try await persistence.flush(Snapshot(value: 3), generation: 3)
        let overwritten = try await persistence.flush(Snapshot(value: 1), generation: 1)
        XCTAssertFalse(overwritten)
        XCTAssertEqual(try recorder.values(), [3])
        XCTAssertFalse(recorder.mainThreadWasUsed)
    }

    func testDebounceCoalescesSliderSnapshotsAndBackgroundFlushDoesNotWait() async throws {
        let recorder = PersistenceRecorder()
        let persistence = DraftPersistence<Snapshot>(destination: URL(fileURLWithPath: "/unused/draft.json"), debounce: .seconds(60), writer: { @Sendable data, destination in try recorder.write(data, destination) })
        for value in 1...100 { _ = await persistence.schedule(Snapshot(value: value), generation: UInt64(value)) }
        XCTAssertEqual(recorder.writeCount, 0)
        _ = try await persistence.flush(Snapshot(value: 101), generation: 101)
        XCTAssertEqual(try recorder.values(), [101])
        let alreadyFlushed = try await persistence.flush()
        XCTAssertFalse(alreadyFlushed)
        XCTAssertEqual(recorder.writeCount, 1)
    }

    func testFailedDebouncedSaveReportsErrorAndCanRetrySameGeneration() async throws {
        let recorder = PersistenceRecorder()
        recorder.failNext = true
        let persistence = DraftPersistence<Snapshot>(destination: URL(fileURLWithPath: "/unused/draft.json"), debounce: .zero, writer: { @Sendable data, destination in try recorder.write(data, destination) })
        _ = await persistence.schedule(Snapshot(value: 42), generation: 1, onFailure: { @Sendable message in recorder.recordFailure(message) })
        for _ in 0..<10_000 {
            if recorder.failureCount > 0 { break }
            await Task.yield()
        }
        XCTAssertEqual(recorder.failureCount, 1)
        _ = try await persistence.flush()
        XCTAssertEqual(try recorder.values(), [42])
        XCTAssertEqual(recorder.writeCount, 2)
    }

    func testOversizedSnapshotNeverReplacesSavedDraft() async throws {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("draft.json")
        defer { try? FileManager.default.removeItem(at: destination.deletingLastPathComponent()) }
        let persistence = DraftPersistence<String>(destination: destination, debounce: .seconds(60), maximumBytes: 100)
        _ = try await persistence.flush("saved", generation: 1)
        do {
            _ = try await persistence.flush(String(repeating: "x", count: 101), generation: 2)
            XCTFail("Expected a bounded draft failure")
        } catch { }
        XCTAssertEqual(try JSONDecoder().decode(String.self, from: Data(contentsOf: destination)), "saved")
    }
}

private struct Snapshot: Codable, Sendable { let value: Int }

private final class PersistenceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var saved: [Data] = []
    private var count = 0
    private var failures = 0
    private var fail = false
    private var usedMain = false
    var writeCount: Int { lock.withLock { count } }
    var failureCount: Int { lock.withLock { failures } }
    var mainThreadWasUsed: Bool { lock.withLock { usedMain } }
    var failNext: Bool {
        get { lock.withLock { fail } }
        set { lock.withLock { fail = newValue } }
    }
    func write(_ data: Data, _ destination: URL) throws {
        try lock.withLock {
            count += 1
            usedMain = usedMain || Thread.isMainThread
            if fail { fail = false; throw RoutePilotError("Injected write failure") }
            saved.append(data)
        }
    }
    func recordFailure(_ message: String) { lock.withLock { failures += 1 } }
    func values() throws -> [Int] { try lock.withLock { try saved.map { try JSONDecoder().decode(Snapshot.self, from: $0).value } } }
}
