import SwiftUI
import UniformTypeIdentifiers
import RoutePilotCore

struct ContentView: View {
    @ObservedObject var model: RoutePilotModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchShown = false
    @State private var setupShown = false
    @State private var exportShown = false
    @State private var importShown = false
    @State private var coordinatesShown = false
    @State private var coordinateText = ""
    @State private var sliderCeiling = 30.0
    @State private var quickStarting = false
    @FocusState private var speedFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    RouteMap(model: model)
                        .frame(height: min(340, max(120, geometry.size.height * 0.38)))
                        .overlay(alignment: .topTrailing) {
                            Button { model.fitRevision += 1 } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").padding(12) }
                                .background(.regularMaterial, in: Circle())
                                .accessibilityLabel("Fit route")
                                .padding(12)
                        }
                        .overlay(alignment: .bottomLeading) {
                            Text(model.canEdit ? "Tap to add · Hold pin to move · Tap pin to remove" : "Stop playback to edit checkpoints")
                                .font(.caption2).padding(7).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7)).padding(8)
                        }
                    Form {
                        movementSection
                        if model.mode != .stationary { speedSection }
                        checkpointSection
                        Section {
                            Toggle("Loop route", isOn: Binding(get: { model.loop }, set: model.setLoop)).disabled(!model.canEdit || model.mode == .stationary)
                            HStack {
                                Button("Reverse", systemImage: "arrow.left.arrow.right", action: model.reverse).disabled(!model.canEdit || model.checkpoints.count < 2)
                                Spacer()
                                Button("Import GPX", systemImage: "square.and.arrow.down") { importShown = true }.disabled(!model.canEdit)
                            }.buttonStyle(.borderless)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("RoutePilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { searchShown = true } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search locations")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { setupShown = true } label: {
                        Label(model.device.isConnected ? "Connected" : "iPhone", systemImage: model.device.isConnected ? "iphone.radiowaves.left.and.right" : "gearshape").font(.subheadline)
                    }.accessibilityLabel("iPhone setup")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { speedFocused = false; dismissKeyboard() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { playbackBar }
            .sheet(isPresented: $searchShown) { LocationSearchView(model: model) }
            .sheet(isPresented: $setupShown) { DeviceSetupView(model: model) }
            .sheet(isPresented: $exportShown) { if let route = model.route { GPXCreatorView(route: route, mode: model.mode, units: model.units, speedKPH: model.speedKPH, loop: model.loop) } }
            .fileImporter(isPresented: $importShown, allowedContentTypes: [UTType(filenameExtension: "gpx") ?? .xml, .xml], allowsMultipleSelection: false) { result in
                do { if let url = try result.get().first { model.importGPX(url) } } catch { model.error = error.localizedDescription }
            }
            .alert("RoutePilot", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
            .alert("Add coordinates", isPresented: $coordinatesShown) {
                TextField("Latitude, longitude", text: $coordinateText).keyboardType(.numbersAndPunctuation)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    let pieces = coordinateText.split(separator: ",", omittingEmptySubsequences: false)
                    guard pieces.count == 2, let latitude = Double(pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)), let longitude = Double(pieces[1].trimmingCharacters(in: .whitespacesAndNewlines)) else { model.error = "Enter latitude, longitude, for example 37.7694, -122.4830."; return }
                    let point = RoutePoint(latitude: latitude, longitude: longitude)
                    guard point.isValid else { model.error = "Latitude must be −90 to 90 and longitude −180 to 180."; return }
                    model.add(point); model.fitRevision += 1
                }
            }
            .onAppear { sliderCeiling = max(model.mode == .driving ? 150 : 30, model.speedKPH) }
            .onChange(of: model.mode) { _, mode in sliderCeiling = max(mode == .driving ? 150 : 30, model.speedKPH) }
            .onChange(of: model.speedKPH) { _, speed in if speed > sliderCeiling { sliderCeiling = min(250, ceil(speed / 10) * 10) } }
            .onChange(of: scenePhase) { _, phase in model.sceneChanged(phase) }
            .onOpenURL { url in if url.pathExtension.lowercased() == "gpx" { model.importGPX(url) } }
        }
    }

    private var movementSection: some View {
        Section {
            Picker("Movement", selection: Binding(get: { model.mode }, set: model.setMode)) {
                ForEach(MovementMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
            }.pickerStyle(.segmented).disabled(!model.canEdit)
            Picker("Units", selection: $model.units) {
                Text("Metric").tag(UnitSystem.metric)
                Text("Imperial").tag(UnitSystem.imperial)
            }.pickerStyle(.segmented)
        } footer: {
            Text(model.mode == .stationary ? "Holds one location." : model.mode == .running ? "Follows pedestrian routes from Apple Maps." : "Follows driving routes from Apple Maps.")
        }
    }

    private var speedSection: some View {
        Section {
            HStack {
                Text("Speed")
                Spacer()
                TextField("Speed", value: Binding(get: { model.units.displaySpeed(model.speedKPH) }, set: { value in
                    guard value.isFinite else { return }
                    model.speedKPH = min(250, max(0.1, model.units.speedKPH(value)))
                }), format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad).focused($speedFocused).multilineTextAlignment(.trailing).frame(width: 85).accessibilityLabel("Speed in \(model.units.speedUnit)")
                Text(model.units.speedUnit).foregroundStyle(.secondary)
            }
            Slider(value: $model.speedKPH, in: 0.1...sliderCeiling, step: 0.1).accessibilityLabel("Adjust speed")
            DisclosureGroup("Variation") {
                Toggle("Vary speed", isOn: $model.varySpeed)
                HStack {
                    Text("± \(model.units.displaySpeed(model.speedVariationKPH), specifier: "%.1f") \(model.units.speedUnit)").font(.caption).monospacedDigit()
                    Slider(value: $model.speedVariationKPH, in: 0...50, step: 0.1).disabled(!model.varySpeed).accessibilityLabel("Speed variation range")
                }
                Toggle("Small lateral drift", isOn: $model.lateralDrift)
                HStack {
                    Text("± \(model.units.displayLateral(model.lateralVariationMeters), specifier: "%.2f") \(model.units.lateralUnit)").font(.caption).monospacedDigit()
                    Slider(value: $model.lateralVariationMeters, in: 0...2, step: 0.05).disabled(!model.lateralDrift).accessibilityLabel("Lateral drift range")
                }
                Text("Smooth variation within the selected limits. Drift fades at corners and endpoints.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var checkpointSection: some View {
        Section {
            ForEach(Array(model.checkpoints.enumerated()), id: \.element.id) { index, checkpoint in
                HStack {
                    Text("\(index + 1)").font(.caption.bold()).frame(width: 28, height: 28).background(Color.accentColor.opacity(0.12), in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(checkpoint.name).font(.subheadline).lineLimit(1)
                        Text(String(format: "%.5f, %.5f", checkpoint.point.latitude, checkpoint.point.longitude)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer()
                    Button { model.remove(checkpoint.id) } label: { Image(systemName: "minus.circle").foregroundStyle(.secondary).frame(width: 44, height: 44) }
                        .buttonStyle(.borderless).disabled(!model.canEdit).accessibilityLabel("Remove checkpoint \(index + 1)")
                }
            }
            if model.checkpoints.isEmpty { Text("Search for a place or tap the map.").font(.subheadline).foregroundStyle(.secondary) }
            HStack {
                Button("Coordinates", systemImage: "plus") { coordinateText = ""; coordinatesShown = true }.disabled(!model.canEdit)
                Spacer()
                Button("Undo", systemImage: "arrow.uturn.backward", action: model.undo).disabled(!model.canEdit || model.historyCount == 0).accessibilityValue("\(model.historyCount) edits available")
            }.buttonStyle(.borderless)
            if !model.checkpoints.isEmpty { Button("Clear checkpoints", role: .destructive, action: model.clearCheckpoints).disabled(!model.canEdit) }
        } header: { Text("Checkpoints · \(model.checkpoints.count)/24").accessibilityIdentifier("checkpointCount") }
    }

    private func startOnDevice() {
        guard !quickStarting else { return }
        guard model.device.pairingImported || model.device.isConnected else { setupShown = true; return }
        quickStarting = true
        Task {
            defer { quickStarting = false }
            do {
                if !model.device.isConnected {
                    setupShown = true
                    let defaults = UserDefaults.standard
                    let automatic = defaults.object(forKey: "connection.automaticPort") as? Bool ?? true
                    let port = automatic ? nil : UInt16(exactly: defaults.integer(forKey: "device.lastPort"))
                    try await model.device.connect(host: defaults.string(forKey: "device.lastHost") ?? "10.7.0.1", port: port)
                }
                try Task.checkCancellation()
                await model.start(preview: false)
                if model.active { setupShown = false }
            } catch is CancellationError { }
            catch { setupShown = true }
        }
    }

    private var playbackBar: some View {
        VStack(spacing: 10) {
            HStack {
                Label(model.displayDistance, systemImage: "point.topleft.down.to.point.bottomright.curvepath").fontWeight(.semibold)
                Spacer()
                if model.calculating || model.starting || model.restoring || model.pausing || quickStarting { ProgressView().controlSize(.small) }
                Text(RoutePilotModel.time(model.active ? model.elapsed : model.duration)).monospacedDigit()
            }.font(.subheadline)
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: model.recoveryRequired && !model.active ? "exclamationmark.triangle" : model.active ? "location.fill" : "info.circle")
                    .foregroundStyle(model.recoveryRequired && !model.active ? Color.orange : Color.secondary)
                Text(model.status).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.caption).foregroundStyle(.secondary).accessibilityElement(children: .combine).accessibilityIdentifier("playbackStatus")
            if model.active && model.totalDistance > 0 {
                ProgressView(value: min(1, model.meters / model.totalDistance)).accessibilityLabel("Route progress")
                if model.mode != .stationary {
                    Text("Current speed \(model.units.displaySpeed(model.currentSpeed), specifier: "%.1f") \(model.units.speedUnit)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            HStack(spacing: 10) {
                if model.active || model.recoveryRequired || model.starting || model.restoring {
                    if model.canPause {
                        Button(model.paused ? "Resume" : "Pause", action: model.togglePause).buttonStyle(.bordered).disabled(model.pausing)
                    }
                    Button {
                        dismissKeyboard()
                        Task { await model.stop() }
                    } label: {
                        Text(model.restoring ? "Restoring…" : model.preview && !model.recoveryRequired ? "Stop preview" : "Restore real location").frame(maxWidth: .infinity, minHeight: 24)
                    }.buttonStyle(.borderedProminent).disabled(!model.canStop)
                } else {
                    Button("Preview") { dismissKeyboard(); Task { await model.start(preview: true) } }
                        .buttonStyle(.bordered).disabled(!model.canStart)
                    Button {
                        dismissKeyboard()
                        startOnDevice()
                    } label: {
                        Label("Start on iPhone", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 24)
                    }.buttonStyle(.borderedProminent).disabled(!model.canStart || quickStarting)
                }
            }.font(.subheadline)
            HStack {
                Button { dismissKeyboard(); exportShown = true } label: { Label("Create GPX", systemImage: "square.and.arrow.up") }
                    .disabled(model.route == nil || model.calculating).accessibilityIdentifier("createGPX")
                Spacer()
                if !model.calculating && model.route == nil && model.checkpoints.count > 1 {
                    Button("Retry route", action: model.recalculate)
                } else {
                    Text(model.active && !model.preview ? "On-device simulation" : "Preview changes no device location").foregroundStyle(.secondary)
                }
            }.font(.caption)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
