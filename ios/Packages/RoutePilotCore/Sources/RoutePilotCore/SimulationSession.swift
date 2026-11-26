import Foundation

/// The device implementation must retain its recovery flag before attempting a
/// write and clear it only after the device acknowledges restoration.
@MainActor public protocol SimulationDevice: AnyObject {
    var isConnected: Bool { get }
    var recoveryRequired: Bool { get }
    func set(latitude: Double, longitude: Double) async throws
    func clear() async throws
}

public struct SimulationSessionState: Sendable {
    public fileprivate(set) var active = false
    public fileprivate(set) var starting = false
    public fileprivate(set) var restoring = false
    public fileprivate(set) var pausing = false
    public fileprivate(set) var paused = false
    public fileprivate(set) var preview = true
    public fileprivate(set) var recoveryRequired = false
    public fileprivate(set) var snapshot: PlaybackSnapshot?
    public fileprivate(set) var failure: String?
    public var canStop: Bool { (active || starting || recoveryRequired) && !restoring }
    public var canStart: Bool { !active && !starting && !restoring && !pausing && !recoveryRequired }
}

/// Serializes the simulation lifecycle around awaited device commands. Device
/// operations are never canceled optimistically: Stop waits for any outstanding
/// write before Clear, and stale completions cannot restart a stopped session.
@MainActor public final class SimulationSession {
    public private(set) var state = SimulationSessionState()
    public var onChange: (() -> Void)?
    private let device: any SimulationDevice
    private var simulation: PlaybackSimulation?
    private var revision = UUID()
    private var pendingWrite: (id: UUID, task: Task<Void, Error>)?
    private var interrupted = false
    private var latestSettings: PlaybackSettings?

    public init(device: any SimulationDevice) {
        self.device = device
        state.recoveryRequired = device.recoveryRequired
        state.preview = !device.recoveryRequired
    }

    public var mode: MovementMode? { simulation?.mode }
    public var canPause: Bool {
        state.active && !state.starting && !state.restoring && !state.pausing && !interrupted && simulation?.mode != .stationary && simulation?.snapshot.phase != .completed && (state.preview || device.isConnected)
    }

    public func synchronizeRecovery() {
        if device.recoveryRequired && !state.recoveryRequired {
            state.recoveryRequired = true
            if !state.active && !state.starting { state.preview = false }
            changed()
        }
    }

    public func start(route: RouteGeometry, mode: MovementMode, settings: PlaybackSettings, loop: Bool, preview: Bool) async throws {
        if device.recoveryRequired { synchronizeRecovery() }
        guard state.canStart else { return }
        guard preview || device.isConnected else { throw RoutePilotError("Open iPhone setup and connect the developer service first.") }
        var candidate = try PlaybackSimulation(route: route, mode: mode, settings: settings, loop: loop)
        latestSettings = settings
        let current = UUID()
        revision = current
        state.starting = true
        state.preview = preview
        state.failure = nil
        interrupted = false
        changed()
        let operation = { @MainActor [self] in
          do {
            guard revision == current, !state.restoring else { return }
            if !preview {
                state.recoveryRequired = true
                changed()
                try await device.set(latitude: candidate.snapshot.position.latitude, longitude: candidate.snapshot.position.longitude)
            }
            guard revision == current, !state.restoring else { return }
            if let latestSettings { try candidate.updateSettings(latestSettings) }
            simulation = candidate
            state.snapshot = candidate.snapshot
            state.active = true
            state.starting = false
            state.paused = false
            changed()
        } catch {
            guard revision == current, !state.restoring else { return }
            state.starting = false
            state.recoveryRequired = !preview || device.recoveryRequired
            state.failure = error.localizedDescription
            interrupted = !preview
            changed()
            throw error
          }
        }
        if preview { try await operation() } else { try await performWrite(operation) }
    }

    public func advance(seconds: TimeInterval) async throws {
        guard state.active, !state.starting, !state.restoring, !state.pausing, !interrupted, pendingWrite == nil, var candidate = simulation else { return }
        let current = revision
        if !state.paused { candidate.advance(seconds: seconds) }
        let operation = { @MainActor [self] in
          do {
            guard revision == current, !state.restoring else { return }
            if !state.preview { try await device.set(latitude: candidate.snapshot.position.latitude, longitude: candidate.snapshot.position.longitude) }
            guard revision == current, !state.restoring else { return }
            if let latestSettings { try candidate.updateSettings(latestSettings) }
            // Pause may have arrived while the device write was in flight. Its
            // final point is now the held point; no subsequent tick advances it.
            if state.paused { candidate.setPaused(true) }
            simulation = candidate
            state.snapshot = candidate.snapshot
            if candidate.snapshot.phase == .completed { state.paused = true }
            changed()
        } catch {
            guard revision == current, !state.restoring else { return }
            state.paused = true
            state.recoveryRequired = !state.preview || device.recoveryRequired
            state.failure = error.localizedDescription
            interrupted = true
            changed()
            throw error
          }
        }
        if state.preview { try await operation() } else { try await performWrite(operation) }
    }

    public func setPaused(_ paused: Bool) async {
        guard canPause else { return }
        let current = revision
        state.pausing = true
        state.paused = paused
        changed()
        // A location write already handed to the device must finish before the
        // interface promises the route is paused at its final held coordinate.
        if let pending = pendingWrite { _ = await pending.task.result }
        guard revision == current, !state.restoring else { return }
        guard !interrupted else { state.pausing = false; changed(); return }
        simulation?.setPaused(paused)
        state.snapshot = simulation?.snapshot
        state.pausing = false
        changed()
    }

    public func updateSettings(_ settings: PlaybackSettings) throws {
        try settings.validate()
        latestSettings = settings
        try simulation?.updateSettings(settings)
        if let snapshot = simulation?.snapshot { state.snapshot = snapshot; changed() }
    }

    public func stop() async throws {
        guard state.canStop else { return }
        let current = UUID()
        revision = current
        state.restoring = true
        state.pausing = false
        state.failure = nil
        changed()
        if let pending = pendingWrite { _ = await pending.task.result }
        do {
            if !state.preview || state.recoveryRequired || device.recoveryRequired { try await device.clear() }
            guard revision == current else { return }
            simulation = nil
            state.active = false
            state.starting = false
            state.paused = false
            state.snapshot = nil
            state.recoveryRequired = false
            state.restoring = false
            interrupted = false
            changed()
        } catch {
            guard revision == current else { return }
            state.starting = false
            state.paused = true
            state.restoring = false
            state.recoveryRequired = true
            state.failure = error.localizedDescription
            interrupted = true
            changed()
            throw error
        }
    }

    private func performWrite(_ operation: @escaping @MainActor () async throws -> Void) async throws {
        let id = UUID()
        let task = Task { @MainActor in try await operation() }
        pendingWrite = (id, task)
        defer { if pendingWrite?.id == id { pendingWrite = nil } }
        try await task.value
    }

    private func changed() { onChange?() }
}
