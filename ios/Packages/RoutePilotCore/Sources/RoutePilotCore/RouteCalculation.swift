import Foundation

public typealias RouteCalculationProvider = @MainActor (_ checkpoints: [RoutePoint], _ mode: MovementMode, _ loop: Bool) async throws -> [RoutePoint]

/// Accepts only the newest calculation, including when a provider completes an
/// old request after cancellation. It never invents a straight-line fallback.
@MainActor public final class RouteCalculation {
    private var revision = UUID()
    private var pending: Task<RouteGeometry, Error>?

    public init() { }

    public func invalidate() {
        revision = UUID()
        pending?.cancel()
        pending = nil
    }

    public func calculate(checkpoints: [RoutePoint], mode: MovementMode, loop: Bool, provider: @escaping RouteCalculationProvider) async throws -> RouteGeometry? {
        try Task.checkCancellation()
        invalidate()
        guard (1...24).contains(checkpoints.count), checkpoints.allSatisfy(\.isValid) else { throw RoutePilotError("Choose 1–24 valid checkpoints.") }
        if mode == .stationary {
            guard checkpoints.count == 1 else { throw RoutePilotError("A stationary location needs one checkpoint.") }
            return try RouteGeometry(points: checkpoints)
        }
        guard checkpoints.count >= 2 else { throw RoutePilotError("Add a second checkpoint for a moving route.") }
        let current = revision
        let task = Task { @MainActor in
            let routed = try await provider(checkpoints, mode, loop)
            try Task.checkCancellation()
            let geometry = try RouteGeometry(points: routed)
            guard geometry.totalDistance >= 0.01 else { throw RoutePilotError("Choose checkpoints farther apart.") }
            if loop, let first = geometry.points.first, let last = geometry.points.last,
               RouteGeometry.distance(first, last) > 1 {
                throw RoutePilotError("The calculated return route is incomplete. Retry or turn off Loop route.")
            }
            return geometry
        }
        pending = task
        do {
            let geometry = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
            guard revision == current else { return nil }
            pending = nil
            return geometry
        } catch {
            guard revision == current else { return nil }
            pending = nil
            throw error
        }
    }
}

/// Binds an offline route to the exact checkpoint draft and routing mode that
/// produced it. Older or mismatched geometry must be recalculated.
public struct RouteCache: Codable, Sendable {
    public let checkpoints: [RoutePoint]
    public let mode: MovementMode
    public let loop: Bool
    public let geometry: [RoutePoint]

    public init(checkpoints: [RoutePoint], mode: MovementMode, loop: Bool, geometry: [RoutePoint]) {
        self.checkpoints = checkpoints
        self.mode = mode
        self.loop = loop
        self.geometry = geometry
    }

    public func restore(checkpoints expected: [RoutePoint], mode expectedMode: MovementMode, loop expectedLoop: Bool) throws -> RouteGeometry? {
        guard checkpoints == expected, mode == expectedMode, loop == expectedLoop,
              (1...24).contains(expected.count), expected.allSatisfy(\.isValid) else { return nil }
        let route = try RouteGeometry(points: geometry)
        if mode == .stationary { return expected.count == 1 && route.points == expected ? route : nil }
        guard expected.count >= 2, route.totalDistance >= 0.01 else { return nil }
        if loop, let first = route.points.first, let last = route.points.last, RouteGeometry.distance(first, last) > 1 { return nil }
        return route
    }
}
