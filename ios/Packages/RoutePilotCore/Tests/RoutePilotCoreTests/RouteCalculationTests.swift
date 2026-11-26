import XCTest
@testable import RoutePilotCore

@MainActor final class RouteCalculationTests: XCTestCase {
    private let points = [RoutePoint(latitude: 37, longitude: -122), RoutePoint(latitude: 37.01, longitude: -122)]

    func testLatePedestrianResponseCannotReplaceNewDrivingRoute() async throws {
        let calculation = RouteCalculation()
        let provider = ControlledRouteProvider()
        let first = Task { try await calculation.calculate(checkpoints: points, mode: .running, loop: false, provider: provider.calculate) }
        await waitUntil { provider.pending[1] != nil }
        let drivingPoints = [points[0], RoutePoint(latitude: 37.005, longitude: -121.999), points[1]]
        let second = Task { try await calculation.calculate(checkpoints: points, mode: .driving, loop: false, provider: provider.calculate) }
        await waitUntil { provider.pending[2] != nil }
        provider.complete(2, with: drivingPoints)
        let driving = try await second.value
        XCTAssertEqual(driving?.points, drivingPoints)
        provider.complete(1, with: points)
        let late = try await first.value
        XCTAssertNil(late)
        XCTAssertEqual(provider.modes, [.running, .driving])
        XCTAssertTrue(provider.sawCancellation.contains(1))
    }

    func testRemovingCheckpointsInvalidatesEvenUncooperativeProvider() async throws {
        let calculation = RouteCalculation()
        let provider = ControlledRouteProvider()
        let request = Task { try await calculation.calculate(checkpoints: points, mode: .running, loop: false, provider: provider.calculate) }
        await waitUntil { provider.pending[1] != nil }
        calculation.invalidate()
        provider.complete(1, with: points)
        let result = try await request.value
        XCTAssertNil(result)
    }

    func testCallerCancellationReachesProviderAndDoesNotReturnGeometry() async throws {
        let calculation = RouteCalculation()
        let provider = ControlledRouteProvider()
        let request = Task { try await calculation.calculate(checkpoints: points, mode: .running, loop: false, provider: provider.calculate) }
        await waitUntil { provider.pending[1] != nil }
        request.cancel()
        provider.complete(1, with: points)
        do { _ = try await request.value; XCTFail("Expected cancellation") } catch is CancellationError { }
        XCTAssertTrue(provider.sawCancellation.contains(1))
    }

    func testStationaryAndInvalidInputsNeverCallRoutingProvider() async throws {
        let calculation = RouteCalculation()
        var calls = 0
        let provider: RouteCalculationProvider = { points, _, _ in calls += 1; return points }
        let fixed = try await calculation.calculate(checkpoints: [points[0]], mode: .stationary, loop: false, provider: provider)
        XCTAssertEqual(fixed?.points, [points[0]])
        for checkpoints in [[], Array(repeating: points[0], count: 25), [RoutePoint(latitude: .nan, longitude: 0)]] {
            do { _ = try await calculation.calculate(checkpoints: checkpoints, mode: .running, loop: false, provider: provider); XCTFail("Expected invalid checkpoints") } catch { }
        }
        XCTAssertEqual(calls, 0)
    }

    func testProviderFailureAndIncompleteLoopHaveNoStraightLineFallback() async throws {
        let calculation = RouteCalculation()
        do {
            _ = try await calculation.calculate(checkpoints: points, mode: .driving, loop: false) { _, _, _ in throw RoutePilotError("Provider unavailable") }
            XCTFail("Expected provider failure")
        } catch { XCTAssertEqual(error.localizedDescription, "Provider unavailable") }
        do {
            _ = try await calculation.calculate(checkpoints: points, mode: .running, loop: true) { points, _, _ in points }
            XCTFail("Expected an incomplete loop to be rejected")
        } catch { }
        let closed = try await calculation.calculate(checkpoints: points, mode: .running, loop: true) { points, _, _ in points + [points[0]] }
        XCTAssertEqual(closed?.points.first, closed?.points.last)
    }

    func testOfflineCacheRequiresSameCheckpointInputsModeAndLoop() throws {
        let cache = RouteCache(checkpoints: points, mode: .running, loop: false, geometry: points)
        XCTAssertEqual(try cache.restore(checkpoints: points, mode: .running, loop: false)?.points, points)
        XCTAssertNil(try cache.restore(checkpoints: points, mode: .driving, loop: false))
        XCTAssertNil(try cache.restore(checkpoints: points.reversed(), mode: .running, loop: false))
        XCTAssertNil(try cache.restore(checkpoints: points, mode: .running, loop: true))
        let incorrectFixed = RouteCache(checkpoints: [points[0]], mode: .stationary, loop: false, geometry: [points[1]])
        XCTAssertNil(try incorrectFixed.restore(checkpoints: [points[0]], mode: .stationary, loop: false))
        let incompleteLoop = RouteCache(checkpoints: points, mode: .running, loop: true, geometry: points)
        XCTAssertNil(try incompleteLoop.restore(checkpoints: points, mode: .running, loop: true))
        let invalid = RouteCache(checkpoints: points, mode: .running, loop: false, geometry: [.init(latitude: 91, longitude: 0)])
        XCTAssertThrowsError(try invalid.restore(checkpoints: points, mode: .running, loop: false))
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("The route provider did not reach the expected state", file: file, line: line)
    }
}

@MainActor private final class ControlledRouteProvider {
    var pending: [Int: CheckedContinuation<[RoutePoint], Error>] = [:]
    var calls = 0
    var modes: [MovementMode] = []
    var sawCancellation: Set<Int> = []
    func calculate(_ points: [RoutePoint], mode: MovementMode, loop: Bool) async throws -> [RoutePoint] {
        calls += 1
        let number = calls
        modes.append(mode)
        let result = try await withCheckedThrowingContinuation { pending[number] = $0 }
        if Task.isCancelled { sawCancellation.insert(number) }
        return result
    }
    func complete(_ number: Int, with points: [RoutePoint]) { pending.removeValue(forKey: number)?.resume(returning: points) }
}
