import XCTest
@testable import RoutePilotCore

@MainActor final class SimulationSessionTests: XCTestCase {
    private func route() throws -> RouteGeometry {
        try RouteGeometry(points: [.init(latitude: 37, longitude: -122), .init(latitude: 37.01, longitude: -122)])
    }

    func testDuplicateStartAndStopDuringFirstWriteNeverRestartAfterClear() async throws {
        let device = FakeSimulationDevice()
        device.blockedWrites = [1]
        let session = SimulationSession(device: device)
        let route = try route()
        let first = Task { try await session.start(route: route, mode: .running, settings: .init(), loop: false, preview: false) }
        await waitUntil { device.pendingWrites[1] != nil }
        XCTAssertTrue(session.state.starting)
        XCTAssertFalse(session.state.canStart)
        try await session.start(route: route, mode: .driving, settings: .init(speedKPH: 50), loop: false, preview: false)
        XCTAssertEqual(device.writeCount, 1)
        let stopping = Task { try await session.stop() }
        await waitUntil { session.state.restoring }
        XCTAssertFalse(session.state.canStop)
        XCTAssertEqual(device.clearCount, 0)
        device.completeWrite(1)
        try await first.value
        try await stopping.value
        XCTAssertEqual(device.events, ["set 1 started", "set 1 finished", "clear started", "clear finished"])
        XCTAssertFalse(session.state.active)
        XCTAssertFalse(session.state.starting)
        XCTAssertFalse(session.state.restoring)
        XCTAssertFalse(session.state.recoveryRequired)
        try await session.advance(seconds: 1)
        XCTAssertEqual(device.writeCount, 1)
    }

    func testStopWaitsForQueuedTickAndNoWritesFollowRestore() async throws {
        let device = FakeSimulationDevice()
        let session = SimulationSession(device: device)
        try await session.start(route: route(), mode: .running, settings: .init(), loop: false, preview: false)
        device.blockedWrites = [2]
        let advancing = Task { try await session.advance(seconds: 1) }
        await waitUntil { device.pendingWrites[2] != nil }
        let stopping = Task { try await session.stop() }
        await waitUntil { session.state.restoring }
        XCTAssertEqual(device.clearCount, 0)
        device.completeWrite(2)
        try await advancing.value
        try await stopping.value
        try await session.advance(seconds: 10)
        XCTAssertEqual(device.writeCount, 2)
        XCTAssertEqual(Array(device.events.suffix(4)), ["set 2 started", "set 2 finished", "clear started", "clear finished"])
        XCTAssertNil(session.state.snapshot)
    }

    func testPauseWaitsForLastWriteAndHoldsItsAcknowledgedPosition() async throws {
        let device = FakeSimulationDevice()
        let session = SimulationSession(device: device)
        try await session.start(route: route(), mode: .running, settings: .init(speedKPH: 36), loop: false, preview: false)
        device.blockedWrites = [2]
        let advancing = Task { try await session.advance(seconds: 1) }
        await waitUntil { device.pendingWrites[2] != nil }
        var pauseFinished = false
        let pausing = Task { await session.setPaused(true); pauseFinished = true }
        await waitUntil { session.state.pausing }
        XCTAssertFalse(pauseFinished)
        device.completeWrite(2)
        try await advancing.value
        await pausing.value
        XCTAssertTrue(pauseFinished)
        XCTAssertTrue(session.state.paused)
        XCTAssertFalse(session.state.pausing)
        let held = try XCTUnwrap(session.state.snapshot)
        XCTAssertEqual(held.meters, 10, accuracy: 1e-9)
        XCTAssertEqual(held.currentSpeedKPH, 0)
        try await session.advance(seconds: 100)
        XCTAssertEqual(session.state.snapshot?.position, held.position)
        XCTAssertEqual(session.state.snapshot?.elapsed, held.elapsed)
        XCTAssertEqual(device.positions.last, held.position)
        await session.setPaused(false)
        try await session.advance(seconds: 1)
        XCTAssertEqual(session.state.snapshot!.meters, 20, accuracy: 1e-9)
    }

    func testMotionChangesDuringWriteAreRetainedByCompletion() async throws {
        let device = FakeSimulationDevice()
        let session = SimulationSession(device: device)
        try await session.start(route: route(), mode: .running, settings: .init(speedKPH: 36), loop: false, preview: false)
        device.blockedWrites = [2]
        let advancing = Task { try await session.advance(seconds: 1) }
        await waitUntil { device.pendingWrites[2] != nil }
        try session.updateSettings(.init(speedKPH: 72))
        device.completeWrite(2)
        try await advancing.value
        XCTAssertEqual(session.state.snapshot?.currentSpeedKPH, 72)
        try await session.advance(seconds: 1)
        XCTAssertEqual(session.state.snapshot!.meters, 30, accuracy: 1e-9)
    }

    func testInterruptedWriteLocksPlaybackUntilExplicitRestore() async throws {
        let device = FakeSimulationDevice()
        let session = SimulationSession(device: device)
        try await session.start(route: route(), mode: .running, settings: .init(), loop: false, preview: false)
        device.failedWrites = [2]
        do { try await session.advance(seconds: 1); XCTFail("Expected a write failure") } catch { }
        XCTAssertTrue(session.state.active)
        XCTAssertTrue(session.state.paused)
        XCTAssertTrue(session.state.recoveryRequired)
        XCTAssertFalse(session.canPause)
        XCTAssertNotNil(session.state.failure)
        try await session.advance(seconds: 1)
        XCTAssertEqual(device.writeCount, 2)
        try await session.stop()
        XCTAssertFalse(session.state.active)
        XCTAssertFalse(session.state.recoveryRequired)
    }

    func testFailedRestoreSurvivesReopeningAndCanBeRetried() async throws {
        let device = FakeSimulationDevice()
        device.recoveryRequired = true
        device.isConnected = false
        device.failClear = true
        let reopened = SimulationSession(device: device)
        XCTAssertTrue(reopened.state.recoveryRequired)
        XCTAssertFalse(reopened.state.preview)
        XCTAssertTrue(reopened.state.canStop)
        do { try await reopened.stop(); XCTFail("Expected restore failure") } catch { }
        XCTAssertTrue(reopened.state.recoveryRequired)
        XCTAssertFalse(reopened.state.restoring)
        try await reopened.start(route: route(), mode: .running, settings: .init(), loop: false, preview: true)
        XCTAssertFalse(reopened.state.active)
        XCTAssertEqual(device.writeCount, 0)
        let reopenedAgain = SimulationSession(device: device)
        XCTAssertTrue(reopenedAgain.state.recoveryRequired)
        device.failClear = false
        try await reopenedAgain.stop()
        XCTAssertFalse(reopenedAgain.state.recoveryRequired)
        try await reopenedAgain.start(route: route(), mode: .running, settings: .init(), loop: false, preview: true)
        XCTAssertTrue(reopenedAgain.state.active)
        XCTAssertEqual(device.writeCount, 0)
    }

    func testDuplicateRestoreAndFailedFirstWriteKeepRecoveryHonest() async throws {
        let device = FakeSimulationDevice()
        device.failedWrites = [1]
        let session = SimulationSession(device: device)
        do { try await session.start(route: route(), mode: .running, settings: .init(), loop: false, preview: false); XCTFail("Expected start failure") } catch { }
        XCTAssertFalse(session.state.active)
        XCTAssertFalse(session.state.starting)
        XCTAssertTrue(session.state.recoveryRequired)
        device.blockClear = true
        let firstStop = Task { try await session.stop() }
        await waitUntil { device.pendingClear != nil }
        try await session.stop()
        XCTAssertEqual(device.clearCount, 1)
        device.completeClear()
        try await firstStop.value
        XCTAssertFalse(session.state.recoveryRequired)
    }

    func testPreviewNeverWritesAndInvalidStartHasNoSideEffects() async throws {
        let device = FakeSimulationDevice()
        let session = SimulationSession(device: device)
        do { try await session.start(route: route(), mode: .running, settings: .init(speedKPH: .nan), loop: false, preview: false); XCTFail("Expected validation failure") } catch { }
        XCTAssertEqual(device.writeCount, 0)
        XCTAssertFalse(session.state.starting)
        try await session.start(route: route(), mode: .running, settings: .init(), loop: false, preview: true)
        try await session.advance(seconds: 1)
        await session.setPaused(true)
        try await session.stop()
        XCTAssertEqual(device.writeCount, 0)
        XCTAssertEqual(device.clearCount, 0)
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("The asynchronous operation did not reach its expected state", file: file, line: line)
    }
}

@MainActor private final class FakeSimulationDevice: SimulationDevice {
    var isConnected = true
    var recoveryRequired = false
    var writeCount = 0
    var clearCount = 0
    var events: [String] = []
    var positions: [RoutePoint] = []
    var blockedWrites: Set<Int> = []
    var failedWrites: Set<Int> = []
    var pendingWrites: [Int: CheckedContinuation<Void, Error>] = [:]
    var failClear = false
    var blockClear = false
    var pendingClear: CheckedContinuation<Void, Error>?

    func set(latitude: Double, longitude: Double) async throws {
        writeCount += 1
        let number = writeCount
        recoveryRequired = true
        events.append("set \(number) started")
        if blockedWrites.contains(number) { try await withCheckedThrowingContinuation { pendingWrites[number] = $0 } }
        defer { events.append("set \(number) finished") }
        if failedWrites.contains(number) { isConnected = false; throw RoutePilotError("Injected disconnected device") }
        positions.append(.init(latitude: latitude, longitude: longitude))
    }

    func clear() async throws {
        clearCount += 1
        events.append("clear started")
        if blockClear { try await withCheckedThrowingContinuation { pendingClear = $0 } }
        defer { events.append("clear finished") }
        if failClear { throw RoutePilotError("Injected failed restore") }
        recoveryRequired = false
        isConnected = false
    }

    func completeWrite(_ number: Int) { pendingWrites.removeValue(forKey: number)?.resume() }
    func completeClear() { pendingClear?.resume(); pendingClear = nil }
}
