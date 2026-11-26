import Foundation
import MapKit
import SwiftUI
import Combine
import RoutePilotCore

struct Checkpoint: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var point: RoutePoint
    var name: String
}

private struct SavedDraft: Codable, Sendable {
    var version = 2
    var checkpoints: [Checkpoint]
    var mode: MovementMode
    var units: UnitSystem
    var speed: Double
    var speedVariation: Double
    var lateralVariation: Double
    var varySpeed: Bool
    var lateralDrift: Bool
    var loop: Bool
    var geometry: [RoutePoint]
    var geometryInputs: [RoutePoint]?
    var geometryMode: MovementMode?
    var geometryLoop: Bool?
}

@MainActor
final class RoutePilotModel: ObservableObject {
    @Published private(set) var checkpoints: [Checkpoint] = []
    @Published private(set) var route: RouteGeometry?
    @Published private(set) var mode: MovementMode = .running
    @Published var units: UnitSystem = .metric { didSet { save() } }
    @Published var speedKPH = 10.0 { didSet { motionChanged() } }
    @Published var speedVariationKPH = 1.0 { didSet { motionChanged() } }
    @Published var lateralVariationMeters = 0.75 { didSet { motionChanged() } }
    @Published var varySpeed = false { didSet { motionChanged() } }
    @Published var lateralDrift = false { didSet { motionChanged() } }
    @Published private(set) var loop = false
    @Published private(set) var calculating = false
    @Published private(set) var status = "Add two checkpoints to begin."
    @Published var error: String?
    @Published var fitRevision = 0
    @Published private(set) var active = false
    @Published private(set) var starting = false
    @Published private(set) var restoring = false
    @Published private(set) var pausing = false
    @Published private(set) var paused = false
    @Published private(set) var preview = true
    @Published private(set) var position: RoutePoint?
    @Published private(set) var meters = 0.0
    @Published private(set) var elapsed = 0.0
    @Published private(set) var currentSpeed = 0.0
    @Published private(set) var recoveryRequired = false
    @Published private(set) var historyCount = 0
    let device: DeviceConnection
    let background = BackgroundLocationSession()
    private let session: SimulationSession
    private let isUITesting: Bool
    private let draftPersistence: DraftPersistence<SavedDraft>
    private var pendingDraft: SavedDraft?
    private var draftGeneration: UInt64 = 0
    private var subscriptions = Set<AnyCancellable>()
    private var history: [([Checkpoint], MovementMode, Bool, Double)] = []
    private var routingTask: Task<Void, Never>?
    private let routeCalculation = RouteCalculation()
    private var playbackTask: Task<Void, Never>?
    private var routeRevision = UUID()
    private var loading = true
    private var batchingDraftChanges = false
    private var inBackground = false
    private var playbackRevision = UUID()

    init() {
        let device = DeviceConnection()
        self.device = device
        self.session = SimulationSession(device: device)
        self.draftPersistence = DraftPersistence(destination: Self.defaultDraftURL)
        #if DEBUG
        self.isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        self.isUITesting = false
        #endif
        session.onChange = { [weak self] in self?.synchronizeSession() }
        device.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        background.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        if isUITesting { loadUITestFixture() } else { load() }
        synchronizeSession()
        if recoveryRequired {
            preview = false
            status = "A previous iPhone session may need restoration. Open setup and tap Restore real location."
        }
        device.$recoveryRequired.sink { [weak self] required in
            // Combine's @Published publisher emits before its stored property
            // changes. Defer reading the transport until the assignment ends.
            guard required else { return }
            Task { @MainActor [weak self] in self?.session.synchronizeRecovery() }
        }.store(in: &subscriptions)
        loading = false
    }

    var canStart: Bool { route != nil && !calculating && session.state.canStart && !starting && !pausing && !device.isBusy }
    var canEdit: Bool { !active && !starting && !pausing && !device.isBusy && !recoveryRequired && !restoring }
    var canPause: Bool { session.canPause && !pausing && !device.isBusy }
    var canStop: Bool { session.state.canStop && !restoring }
    var totalDistance: Double { route?.totalDistance ?? 0 }
    var duration: Double { totalDistance / (speedKPH / 3.6) }
    var displayDistance: String { String(format: "%.2f %@", units.displayDistance(totalDistance), units.distanceUnit) }
    var settings: PlaybackSettings {
        PlaybackSettings(speedKPH: speedKPH, speedVariationKPH: varySpeed ? speedVariationKPH : 0, lateralVariationMeters: lateralDrift ? lateralVariationMeters : 0)
    }

    func setMode(_ value: MovementMode) {
        guard canEdit, mode != value else { return }
        remember()
        batchingDraftChanges = true
        mode = value
        speedKPH = value.defaultSpeedKPH
        if value == .stationary {
            loop = false
            if let first = checkpoints.first { checkpoints = [first] }
        }
        batchingDraftChanges = false
        recalculate()
    }

    func setLoop(_ value: Bool) {
        guard canEdit, mode != .stationary, loop != value else { return }
        remember(); loop = value; recalculate()
    }

    func add(_ point: RoutePoint, name: String? = nil) {
        guard canEdit, point.isValid else { return }
        if mode != .stationary && checkpoints.count >= 24 { error = "Use up to 24 checkpoints."; return }
        remember()
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let checkpoint = Checkpoint(point: point, name: trimmedName.isEmpty ? "Checkpoint \(mode == .stationary ? 1 : checkpoints.count + 1)" : String(trimmedName.prefix(200)))
        if mode == .stationary { checkpoints = [checkpoint] } else { checkpoints.append(checkpoint) }
        recalculate()
    }

    func move(_ id: UUID, to point: RoutePoint) {
        guard canEdit, point.isValid, let index = checkpoints.firstIndex(where: { $0.id == id }) else { return }
        guard RouteGeometry.distance(checkpoints[index].point, point) > 0.001 else { return }
        remember(); checkpoints[index].point = point; recalculate()
    }

    func remove(_ id: UUID) {
        guard canEdit, checkpoints.contains(where: { $0.id == id }) else { return }
        remember(); checkpoints.removeAll { $0.id == id }; recalculate()
    }

    func clearCheckpoints() {
        guard canEdit, !checkpoints.isEmpty else { return }
        remember(); checkpoints = []; recalculate()
    }

    func reverse() {
        guard canEdit, checkpoints.count > 1 else { return }
        remember(); checkpoints.reverse(); recalculate()
    }

    func undo() {
        guard canEdit, let previous = history.popLast() else { return }
        let changedMode = mode != previous.1
        batchingDraftChanges = true
        checkpoints = previous.0; mode = previous.1; loop = previous.2
        if changedMode { speedKPH = previous.3 }
        batchingDraftChanges = false
        historyCount = history.count; recalculate()
    }

    private func remember() {
        history.append((checkpoints, mode, loop, speedKPH))
        if history.count > 50 { history.removeFirst() }
        historyCount = history.count
    }

    func recalculate() {
        guard canEdit else { return }
        routingTask?.cancel()
        routeCalculation.invalidate()
        let revision = UUID(); routeRevision = revision
        route = nil; position = nil; error = nil; calculating = false
        save()
        guard let first = checkpoints.first else { status = "Add \(mode == .stationary ? "a checkpoint" : "two checkpoints") to begin."; return }
        if mode == .stationary {
            route = try? RouteGeometry(points: [first.point]); status = "Stationary location ready."; save(); return
        }
        guard checkpoints.count > 1 else { status = "Add a second checkpoint."; return }
        if isUITesting {
            // The UI test fixture never calls Apple Maps or developer services.
            // Release builds cannot enable this branch using launch arguments.
            route = try? RouteGeometry(points: checkpoints.map(\.point), loop: loop)
            status = "\(mode == .running ? "Pedestrian" : "Driving") route ready."
            fitRevision += 1
            return
        }
        calculating = true
        let points = checkpoints.map(\.point), transport: MKDirectionsTransportType = mode == .running ? .walking : .automobile
        let closeLoop = loop
        status = "Finding \(mode == .running ? "a pedestrian" : "a driving") route…"
        routingTask = Task { [weak self] in
            do {
                guard let geometry = try await self?.routeCalculation.calculate(checkpoints: points, mode: transport == .walking ? .running : .driving, loop: closeLoop, provider: { points, mode, loop in
                    try await Self.calculate(points: points, transport: mode == .running ? .walking : .automobile, loop: loop)
                }) else { return }
                try Task.checkCancellation()
                guard let self, self.routeRevision == revision else { return }
                self.route = geometry
                self.calculating = false
                self.status = "\(self.mode == .running ? "Pedestrian" : "Driving") route ready."
                self.fitRevision += 1
                self.save()
            } catch is CancellationError { } catch {
                guard let self, self.routeRevision == revision else { return }
                self.calculating = false
                self.status = "Route unavailable. Move a checkpoint or retry."
                self.error = error.localizedDescription
            }
        }
    }

    private static func calculate(points: [RoutePoint], transport: MKDirectionsTransportType, loop: Bool) async throws -> [RoutePoint] {
        guard (2...24).contains(points.count), points.allSatisfy(\.isValid) else { throw RoutePilotError("Choose 2–24 valid checkpoints.") }
        let started = ContinuousClock.now
        var through = points
        if loop, let first = points.first, let last = points.last, RouteGeometry.distance(first, last) > 0.001 { through.append(first) }
        var result: [RoutePoint] = []
        for index in 1..<through.count {
            try Task.checkCancellation()
            if RouteGeometry.distance(through[index - 1], through[index]) <= 0.001 { continue }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: through[index - 1].coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: through[index].coordinate))
            request.transportType = transport
            request.requestsAlternateRoutes = false
            let directions = MKDirections(request: request)
            let elapsed = started.duration(to: .now)
            let remaining = 90 - Double(elapsed.components.seconds) - Double(elapsed.components.attoseconds) / 1e18
            guard remaining > 0 else { throw RoutePilotError("Route calculation timed out. Use fewer checkpoints or retry.") }
            let response = try await timedDirections(directions, seconds: min(25, remaining))
            guard let leg = response.routes.first else { throw RoutePilotError("Apple Maps could not find a route between these checkpoints.") }
            let coordinates = leg.polyline.points()
            for i in 0..<leg.polyline.pointCount {
                let coordinate = coordinates[i].coordinate
                let p = RoutePoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
                guard p.isValid else { throw RoutePilotError("The routing service returned invalid coordinates.") }
                if result.last.map({ RouteGeometry.distance($0, p) > 0.001 }) ?? true { result.append(p) }
                guard result.count <= RouteGeometry.maximumPoints else { throw RoutePilotError("This route is too detailed. Choose a shorter route.") }
            }
        }
        return result
    }

    private static func timedDirections(_ directions: MKDirections, seconds: Double) async throws -> MKDirections.Response {
        try await withTaskCancellationHandler(operation: {
            try await withThrowingTaskGroup(of: MKDirections.Response.self) { group in
                group.addTask { try await directions.calculate() }
                group.addTask {
                    try await Task.sleep(for: .seconds(seconds))
                    directions.cancel()
                    throw RoutePilotError("Apple Maps timed out. Check your connection, then retry the route.")
                }
                defer { group.cancelAll() }
                guard let response = try await group.next() else { throw CancellationError() }
                return response
            }
        }, onCancel: { directions.cancel() })
    }

    func start(preview: Bool) async {
        guard canStart, let route else { return }
        let revision = UUID()
        playbackRevision = revision
        error = nil
        do {
            try await session.start(route: route, mode: mode, settings: settings, loop: mode != .stationary && loop, preview: preview)
            guard playbackRevision == revision, session.state.active, !session.state.restoring else { return }
            if !preview { background.begin() }
            UIApplication.shared.isIdleTimerDisabled = true
            status = mode == .stationary ? (preview ? "Preview holding position." : "iPhone holding position.") : (preview ? "Preview running." : "iPhone route running.")
            launchPlayback()
        } catch {
            guard playbackRevision == revision else { return }
            self.error = error.localizedDescription
            if recoveryRequired { status = "Starting was interrupted. Restore real location before continuing." }
        }
    }

    private func launchPlayback() {
        playbackTask?.cancel()
        let revision = playbackRevision
        playbackTask = Task { [weak self] in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { break }
                guard let self, self.active, !self.restoring, self.playbackRevision == revision else { break }
                let now = ContinuousClock.now
                let elapsed = last.duration(to: now)
                let dt = min(2, max(0, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18))
                last = now
                if self.preview && self.inBackground { continue }
                do {
                    try await self.session.advance(seconds: dt)
                    guard !Task.isCancelled, self.playbackRevision == revision, !self.restoring else { break }
                    if self.session.state.snapshot?.phase == .completed {
                        self.status = self.preview ? "Preview completed." : "Route completed. Restore real location when finished."
                        if self.preview { UIApplication.shared.isIdleTimerDisabled = false; break }
                    }
                } catch {
                    guard !Task.isCancelled, self.playbackRevision == revision, !self.restoring else { break }
                    self.status = "Connection interrupted. Reconnect, then restore real location."
                    self.error = error.localizedDescription
                    self.background.end()
                    UIApplication.shared.isIdleTimerDisabled = false
                    break
                }
            }
        }
    }

    func togglePause() {
        guard canPause else { return }
        let target = !paused
        let revision = playbackRevision
        pausing = true
        Task { [weak self] in
            guard let self else { return }
            await self.session.setPaused(target)
            guard self.playbackRevision == revision, !self.restoring else { return }
            self.synchronizeSession()
            if self.session.state.failure == nil {
                self.status = self.paused ? "Paused at the current position." : (self.preview ? "Preview running." : "iPhone route running.")
            }
        }
    }

    func stop() async {
        session.synchronizeRecovery()
        guard session.state.canStop else { return }
        playbackRevision = UUID()
        let endingPlayback = playbackTask
        endingPlayback?.cancel()
        playbackTask = nil
        background.end()
        UIApplication.shared.isIdleTimerDisabled = false
        do {
            try await session.stop()
            await endingPlayback?.value
            status = preview ? "Preview stopped." : "Restore command succeeded. Verify your real position in Maps."
        } catch {
            await endingPlayback?.value
            self.error = "Real location could not be restored: \(error.localizedDescription)"
            status = "Reconnect and retry Restore. Restart the iPhone if needed."
        }
    }

    private func synchronizeSession() {
        let state = session.state
        active = state.active
        starting = state.starting
        restoring = state.restoring
        pausing = state.pausing
        paused = state.paused
        preview = state.preview
        recoveryRequired = state.recoveryRequired
        position = state.snapshot?.position
        meters = state.snapshot?.meters ?? 0
        elapsed = state.snapshot?.elapsed ?? 0
        currentSpeed = state.snapshot?.currentSpeedKPH ?? 0
    }

    func sceneChanged(_ phase: ScenePhase) {
        inBackground = phase != .active
        if phase == .background { flushPendingDraft() }
        guard active, preview else { return }
        if inBackground { status = "Preview pauses while the app is hidden." }
        else if session.state.snapshot?.phase == .completed { status = "Preview completed." }
        else { status = paused ? "Paused at the current position." : "Preview running." }
    }

    private func motionChanged() {
        guard !loading, !batchingDraftChanges else { return }
        do { try session.updateSettings(settings) } catch { self.error = error.localizedDescription }
        save()
    }

    func importGPX(_ url: URL) {
        guard canEdit else { error = "Stop the current session and restore real location before importing checkpoints."; return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 4_000_000 else { throw RoutePilotError("Choose a GPX file smaller than 4 MB.") }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: 4_000_001) ?? Data()
            guard data.count <= 4_000_000 else { throw RoutePilotError("Choose a GPX file smaller than 4 MB.") }
            let points = try GPXDocument.importCheckpoints(data, maxCheckpoints: 24)
            remember()
            batchingDraftChanges = true
            checkpoints = points.enumerated().map { Checkpoint(point: $0.element, name: "Checkpoint \($0.offset + 1)") }
            let importedMode: MovementMode = points.count == 1 ? .stationary : mode == .stationary ? .running : mode
            if importedMode != mode { mode = importedMode; speedKPH = mode.defaultSpeedKPH }
            loop = false
            batchingDraftChanges = false
            recalculate(); fitRevision += 1
        } catch { self.error = error.localizedDescription }
    }

    private static var defaultDraftURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("RoutePilot/draft.json")
    }
    private var draftURL: URL { Self.defaultDraftURL }

    private func save() {
        guard !loading, !batchingDraftChanges, !isUITesting else { return }
        let draft = SavedDraft(checkpoints: checkpoints, mode: mode, units: units, speed: speedKPH, speedVariation: speedVariationKPH, lateralVariation: lateralVariationMeters, varySpeed: varySpeed, lateralDrift: lateralDrift, loop: loop, geometry: route?.points ?? [], geometryInputs: route == nil ? nil : checkpoints.map(\.point), geometryMode: route == nil ? nil : mode, geometryLoop: route == nil ? nil : loop)
        draftGeneration &+= 1
        let generation = draftGeneration
        pendingDraft = draft
        let persistence = draftPersistence
        Task { [weak self] in
            await persistence.schedule(draft, generation: generation) { [weak self] message in
                Task { @MainActor [weak self] in
                    guard let self, self.draftGeneration == generation else { return }
                    self.error = "The route draft could not be saved on this iPhone. \(message)"
                }
            }
        }
    }

    private func flushPendingDraft() {
        guard !isUITesting, let draft = pendingDraft else { return }
        let generation = draftGeneration
        let persistence = draftPersistence
        let backgroundTask = DraftSaveBackgroundTask()
        Task { [weak self] in
            do { try await persistence.flush(draft, generation: generation) }
            catch {
                if let self, self.draftGeneration == generation { self.error = "The route draft could not be saved on this iPhone. \(error.localizedDescription)" }
            }
            backgroundTask.finish()
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: draftURL.path) else { return }
        do {
            let file = try FileHandle(forReadingFrom: draftURL)
            defer { try? file.close() }
            let data = try file.read(upToCount: 4_000_001) ?? Data()
            guard data.count <= 4_000_000 else { throw RoutePilotError("Saved draft is too large.") }
            let draft = try JSONDecoder().decode(SavedDraft.self, from: data)
            guard (1...2).contains(draft.version), draft.checkpoints.count <= 24, Set(draft.checkpoints.map(\.id)).count == draft.checkpoints.count, draft.checkpoints.allSatisfy({ $0.point.isValid && $0.name.count <= 200 }), (0.1...250).contains(draft.speed), (0...50).contains(draft.speedVariation), (0...2).contains(draft.lateralVariation), draft.mode != .stationary || draft.checkpoints.count <= 1 else { throw RoutePilotError("Saved draft is invalid.") }
            checkpoints = draft.checkpoints; mode = draft.mode; units = draft.units
            speedKPH = draft.speed; speedVariationKPH = draft.speedVariation; lateralVariationMeters = draft.lateralVariation
            varySpeed = draft.varySpeed; lateralDrift = draft.lateralDrift; loop = draft.loop
            if draft.version == 2, let inputs = draft.geometryInputs, let geometryMode = draft.geometryMode, let geometryLoop = draft.geometryLoop, !draft.geometry.isEmpty {
                let cache = RouteCache(checkpoints: inputs, mode: geometryMode, loop: geometryLoop, geometry: draft.geometry)
                if let restored = try? cache.restore(checkpoints: checkpoints.map(\.point), mode: mode, loop: loop) {
                    route = restored; status = "Saved \(mode == .stationary ? "stationary location" : "route") ready."
                } else { recalculate() }
            } else if !checkpoints.isEmpty { recalculate() }
        } catch { self.error = "Could not load the saved route. Add checkpoints to start again." }
    }

    private func loadUITestFixture() {
        #if DEBUG
        checkpoints = [
            Checkpoint(point: RoutePoint(latitude: 37.76945, longitude: -122.49050), name: "Checkpoint 1"),
            Checkpoint(point: RoutePoint(latitude: 37.77090, longitude: -122.48725), name: "Checkpoint 2"),
            Checkpoint(point: RoutePoint(latitude: 37.77175, longitude: -122.48213), name: "Checkpoint 3")
        ]
        route = try? RouteGeometry(points: checkpoints.map(\.point))
        status = "Pedestrian route ready."
        #endif
    }

    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let s = Int(min(seconds, 999_999_999))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

extension DeviceConnection: SimulationDevice { }

@MainActor private final class DraftSaveBackgroundTask {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    init() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Save route draft") { [weak self] in
            Task { @MainActor [weak self] in self?.finish() }
        }
    }
    func finish() {
        guard identifier != .invalid else { return }
        let completed = identifier
        identifier = .invalid
        UIApplication.shared.endBackgroundTask(completed)
    }
}

extension RoutePoint {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}
