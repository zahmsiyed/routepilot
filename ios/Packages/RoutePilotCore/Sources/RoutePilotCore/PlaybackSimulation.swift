import Foundation

public struct PlaybackSettings: Codable, Equatable, Sendable {
    public var speedKPH: Double
    public var speedVariationKPH: Double
    public var lateralVariationMeters: Double
    public init(speedKPH: Double = 10, speedVariationKPH: Double = 0, lateralVariationMeters: Double = 0) {
        self.speedKPH = speedKPH
        self.speedVariationKPH = speedVariationKPH
        self.lateralVariationMeters = lateralVariationMeters
    }
    public func validate() throws {
        guard speedKPH.isFinite, (0.1...250).contains(speedKPH) else { throw RoutePilotError("Enter a speed between 0.1 and 250 km/h.") }
        guard speedVariationKPH.isFinite, (0...50).contains(speedVariationKPH) else { throw RoutePilotError("Choose a speed variation between 0 and 50 km/h.") }
        guard lateralVariationMeters.isFinite, (0...2).contains(lateralVariationMeters) else { throw RoutePilotError("Choose a lateral variation between 0 and 2 meters.") }
    }
}

public enum PlaybackPhase: String, Sendable { case playing, holding, paused, completed }

public struct PlaybackSnapshot: Sendable {
    public let phase: PlaybackPhase
    public let position: RoutePoint
    public let elapsed: TimeInterval
    public let meters: Double
    public let currentSpeedKPH: Double
    public let lateralOffsetMeters: Double
    public let laps: Int
}

/// Advances only when explicitly ticked. Callers should suspend ticks in the
/// background rather than treating suspension time as recorded movement.
public struct PlaybackSimulation: Sendable {
    public let route: RouteGeometry
    public let mode: MovementMode
    public let loop: Bool
    public private(set) var settings: PlaybackSettings
    public private(set) var snapshot: PlaybackSnapshot
    private var speedNoise: SmoothVariation
    private var lateralNoise: SmoothVariation

    public init(route: RouteGeometry, mode: MovementMode, settings: PlaybackSettings = .init(), loop: Bool = false, seed: UInt64 = 0x5275746550696C6F) throws {
        try settings.validate()
        guard mode == .stationary || route.totalDistance >= 0.01 else { throw RoutePilotError("A moving simulation needs two distinct route points.") }
        guard mode != .stationary || route.points.count == 1 else { throw RoutePilotError("A stationary simulation needs one location.") }
        self.route = route
        self.mode = mode
        self.loop = loop && mode != .stationary
        self.settings = settings
        self.speedNoise = SmoothVariation(seed: seed, minimumDuration: 6)
        self.lateralNoise = SmoothVariation(seed: seed ^ 0x49D625D8, minimumDuration: 8)
        self.snapshot = PlaybackSnapshot(phase: mode == .stationary ? .holding : .playing, position: route.points[0], elapsed: 0, meters: 0, currentSpeedKPH: mode == .stationary ? 0 : settings.speedKPH, lateralOffsetMeters: 0, laps: 0)
    }

    public mutating func updateSettings(_ newSettings: PlaybackSettings) throws {
        try newSettings.validate()
        settings = newSettings
        refresh(phase: snapshot.phase)
    }

    public mutating func setPaused(_ paused: Bool) {
        guard snapshot.phase == .playing || snapshot.phase == .paused else { return }
        refresh(phase: paused ? .paused : .playing)
    }

    /// Large timer gaps advance at most two seconds, preventing a jump after a
    /// stalled thread or device suspension. No time passes while paused.
    @discardableResult public mutating func advance(seconds: TimeInterval) -> PlaybackSnapshot {
        guard seconds.isFinite, seconds > 0, snapshot.phase == .playing || snapshot.phase == .holding else { return snapshot }
        let delta = min(seconds, 2)
        guard snapshot.phase == .playing else {
            snapshot = PlaybackSnapshot(phase: .holding, position: route.points[0], elapsed: snapshot.elapsed + delta, meters: 0, currentSpeedKPH: 0, lateralOffsetMeters: 0, laps: 0)
            return snapshot
        }
        speedNoise.advance(seconds: delta)
        lateralNoise.advance(seconds: delta)
        var phase = snapshot.phase
        let speed = (settings.speedKPH + settings.speedVariationKPH * speedNoise.value).clamped(0.1, 250)
        var meters = snapshot.meters + (snapshot.currentSpeedKPH + speed) * delta / 7.2
        var laps = snapshot.laps
        if meters >= route.totalDistance {
            if loop {
                let completedLaps = floor(meters / route.totalDistance)
                // Finite route/speed/time bounds make this conversion bounded.
                laps += Int(completedLaps)
                meters.formTruncatingRemainder(dividingBy: route.totalDistance)
            } else { meters = route.totalDistance; phase = .completed }
        }
        let lateral = route.lateralPosition(atDistance: meters, offset: settings.lateralVariationMeters * lateralNoise.value)
        snapshot = PlaybackSnapshot(phase: phase, position: lateral.point, elapsed: snapshot.elapsed + delta, meters: meters, currentSpeedKPH: phase == .completed ? 0 : speed, lateralOffsetMeters: lateral.offset, laps: laps)
        return snapshot
    }

    private mutating func refresh(phase: PlaybackPhase) {
        let moving = phase == .playing
        let lateral = route.lateralPosition(atDistance: snapshot.meters, offset: settings.lateralVariationMeters * lateralNoise.value)
        let holdingPosition = phase == .paused
        snapshot = PlaybackSnapshot(phase: phase, position: holdingPosition ? snapshot.position : lateral.point, elapsed: snapshot.elapsed, meters: snapshot.meters, currentSpeedKPH: moving ? (settings.speedKPH + settings.speedVariationKPH * speedNoise.value).clamped(0.1, 250) : 0, lateralOffsetMeters: holdingPosition ? snapshot.lateralOffsetMeters : lateral.offset, laps: snapshot.laps)
    }
}

private struct SmoothVariation: Sendable {
    var value = 0.0
    private var start = 0.0
    private var elapsed = 0.0
    private var duration: Double
    private var target: Double
    private var state: UInt64
    private let minimumDuration: Double

    init(seed: UInt64, minimumDuration: Double) {
        self.state = seed == 0 ? 1 : seed
        self.minimumDuration = minimumDuration
        self.duration = minimumDuration
        self.target = 0
        self.next()
    }
    mutating func advance(seconds: Double) {
        elapsed += seconds
        while elapsed >= duration { elapsed -= duration; start = target; next() }
        let fraction = elapsed / duration
        value = start + (target - start) * fraction * fraction * (3 - 2 * fraction)
    }
    private mutating func random() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
    private mutating func next() {
        target = random() * 2 - 1
        duration = minimumDuration * (1 + random())
    }
}
