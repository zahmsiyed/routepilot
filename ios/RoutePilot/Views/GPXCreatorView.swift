import SwiftUI
import RoutePilotCore

struct GPXCreatorView: View {
    let route: RouteGeometry
    let mode: MovementMode
    let units: UnitSystem
    let speedKPH: Double
    let loop: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var name = "RoutePilot simulated run"
    @State private var format: GPXFormat = .track
    @State private var startTime = Date()
    @State private var useDuration = false
    @State private var pace = "6:00"
    @State private var minutes = "20"
    @State private var creating = false
    @State private var error: String?
    @State private var output: URL?
    @State private var initialized = false

    private var moving: Bool { mode != .stationary && route.totalDistance >= 0.01 }
    private var timed: Bool { format != .route }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(format: "%.2f %@%@", units.displayDistance(route.totalDistance), units.distanceUnit, loop && moving ? " · One lap" : ""))
                    TextField("Name", text: $name).accessibilityLabel("GPX name")
                    Picker("File type", selection: $format) {
                        if moving { Text("Timed track").tag(GPXFormat.track) }
                        Text("Planned route").tag(GPXFormat.route)
                        Text("Xcode waypoints").tag(GPXFormat.xcode)
                    }
                }
                if timed {
                    Section {
                        DatePicker("Start time", selection: $startTime, in: Date(timeIntervalSince1970: 0)..., displayedComponents: [.date, .hourAndMinute])
                        if moving {
                            Picker("Set timing by", selection: $useDuration) { Text("Pace").tag(false); Text("Duration").tag(true) }.pickerStyle(.segmented)
                            if useDuration {
                                HStack { Text("Duration (minutes)"); TextField("20", text: $minutes).keyboardType(.decimalPad).accessibilityLabel("Duration in minutes").multilineTextAlignment(.trailing) }
                            } else {
                                HStack { Text("Pace (min/\(units.distanceUnit))"); TextField("6:00", text: $pace).keyboardType(.numbersAndPunctuation).accessibilityLabel("Pace in minutes per \(units.distanceUnit)").multilineTextAlignment(.trailing) }
                            }
                            if let speed = try? exportSpeed() {
                                let seconds = route.totalDistance / (speed / 3.6)
                                Text("\(RoutePilotModel.time(seconds)) · Ends \(startTime.addingTimeInterval(seconds).formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } footer: { Text("Defaults to finishing now. The file stores UTC timestamps. Live speed variation and lateral drift are not included.") }
                }
                Section {
                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                    }
                    Button {
                        dismissKeyboard(); create()
                    } label: { HStack { Text(creating ? "Creating…" : "Create GPX"); Spacer(); if creating { ProgressView() } else { Image(systemName: "doc.badge.plus") } } }.disabled(creating || validationMessage != nil).accessibilityIdentifier("createExportFile")
                    if let output {
                        ShareLink(item: output) { Label("Save to Files or share GPX", systemImage: "square.and.arrow.up") }
                        Text("Choose Save to Files in the share sheet to keep the GPX on this iPhone.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                }
                DisclosureGroup("Using a file with Strava") {
                    Text("Choose Timed track for an activity file, or Planned route for navigation without timestamps. Generated tracks are labeled as simulated. Review activity type and time before uploading; keep test simulations labeled and private.").font(.caption).foregroundStyle(.secondary)
                    Link("Open Strava file uploader", destination: URL(string: "https://www.strava.com/upload/select")!)
                    Text("A GPX upload does not automatically qualify as Virtual Run. Strava requires a supported recording integration. Account import has not been verified.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(creating)
            .navigationTitle("Create GPX").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(creating) }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } }
            }
            .interactiveDismissDisabled(creating)
            .onAppear {
                guard !initialized else { return }; initialized = true
                format = moving ? .track : .route
                name = moving ? "RoutePilot simulated \(mode == .running ? "run" : "drive")" : "RoutePilot location"
                let scale = units.metersPerDistanceUnit * 3.6
                let seconds = max(Int(ceil(scale / 250)), min(Int(floor(scale / 0.1)), Int((scale / speedKPH).rounded())))
                pace = String(format: "%d:%02d", seconds / 60, seconds % 60)
                minutes = String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), route.totalDistance / (speedKPH / 3.6) / 60)
                let actualSpeed = (try? exportSpeed()) ?? speedKPH
                startTime = Date().addingTimeInterval(-route.totalDistance / (actualSpeed / 3.6))
            }
            .onChange(of: name) { _, _ in output = nil }
            .onChange(of: format) { _, _ in output = nil }
            .onChange(of: startTime) { _, _ in output = nil }
            .onChange(of: pace) { _, _ in output = nil }
            .onChange(of: minutes) { _, _ in output = nil }
            .onChange(of: useDuration) { _, _ in output = nil }
        }
    }

    private var validationMessage: String? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, cleanName.count <= 100 else { return "Enter a name of 1–100 characters." }
        do {
            let speed = try exportSpeed()
            if timed && route.totalDistance / (speed / 3.6) > 365 * 86_400 { return "Choose timing shorter than one year." }
            return nil
        } catch { return error.localizedDescription }
    }

    private func exportSpeed() throws -> Double {
        if !moving || !timed { return speedKPH }
        let speed: Double
        if useDuration {
            guard let value = Double(minutes.replacingOccurrences(of: ",", with: ".")), value.isFinite, value > 0 else { throw RoutePilotError("Enter a positive duration in minutes.") }
            speed = route.totalDistance * 3.6 / (value * 60)
        } else {
            let pieces = pace.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count == 2, pieces[0].count <= 4, let min = Int(pieces[0]), min >= 0, pieces[1].count == 2, let sec = Int(pieces[1]), (0...59).contains(sec), min * 60 + sec > 0 else { throw RoutePilotError("Enter pace as minutes:seconds, for example 6:00.") }
            speed = units.metersPerDistanceUnit * 3.6 / Double(min * 60 + sec)
        }
        guard speed.isFinite, (0.1...250).contains(speed) else { throw RoutePilotError("Choose timing equivalent to 0.1–250 km/h.") }
        return speed
    }

    private func create() {
        do {
            let speed = try exportSpeed(), selectedFormat = format, chosenName = name, chosenStart = startTime
            creating = true; error = nil; output = nil
            Task {
                do {
                    let data = try await Task.detached(priority: .userInitiated) { try GPXDocument.export(route: route, format: selectedFormat, name: chosenName, startTime: chosenStart, speedKPH: speed, mode: mode) }.value
                    let exports = FileManager.default.temporaryDirectory.appendingPathComponent("RoutePilotExports", isDirectory: true)
                    try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
                    // Keep recent share-sheet URLs alive; expire only our old exports.
                    for item in (try? FileManager.default.contentsOfDirectory(at: exports, includingPropertiesForKeys: [.creationDateKey])) ?? [] {
                        if let created = try? item.resourceValues(forKeys: [.creationDateKey]).creationDate, created < Date().addingTimeInterval(-86_400) { try? FileManager.default.removeItem(at: item) }
                    }
                    let directory = exports.appendingPathComponent(UUID().uuidString, isDirectory: true)
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let url = directory.appendingPathComponent(GPXDocument.filename(chosenName))
                    try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
                    output = url
                } catch { self.error = error.localizedDescription }
                creating = false
            }
        } catch { self.error = error.localizedDescription }
    }
}
