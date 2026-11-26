import SwiftUI
import UniformTypeIdentifiers

struct DeviceSetupView: View {
    @ObservedObject var model: RoutePilotModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var importShown = false
    @State private var hostText = UserDefaults.standard.string(forKey: "device.lastHost") ?? "10.7.0.1"
    @State private var portText = String(UserDefaults.standard.integer(forKey: "device.lastPort") == 0 ? 49152 : UserDefaults.standard.integer(forKey: "device.lastPort"))
    @State private var automaticPort = UserDefaults.standard.object(forKey: "connection.automaticPort") as? Bool ?? true
    @State private var localError: String?
    @State private var attemptStarted: Date?
    @State private var copied = false

    private var locked: Bool { model.device.isBusy || model.device.isConnected || model.recoveryRequired || model.active || model.starting || model.restoring }
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))"
    }

    var body: some View {
        NavigationStack {
            Form {
                connectionSection
                if model.device.isBusy || !model.device.progress.isEmpty || model.device.lastError != nil {
                    statusSection
                }
                Section {
                    DisclosureGroup("Advanced connection settings") {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Device address").font(.caption).foregroundStyle(.secondary)
                            TextField("10.7.0.1", text: $hostText)
                                .keyboardType(.decimalPad).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .accessibilityLabel("Device address")
                            Text("Use Device IP from LocalDevVPN, not Tunnel IP. A /32 suffix is accepted.").font(.caption).foregroundStyle(.secondary)
                        }
                        Toggle("Find port automatically", isOn: $automaticPort)
                            .accessibilityIdentifier("automaticPort")
                            .onChange(of: automaticPort) { _, value in UserDefaults.standard.set(value, forKey: "connection.automaticPort") }
                        if !automaticPort {
                            HStack {
                                Text("Developer port")
                                TextField("49152", text: $portText).keyboardType(.numberPad).multilineTextAlignment(.trailing).accessibilityLabel("Developer port")
                            }
                        }
                        Text("Automatic tries the saved connection first, then discovers this iPhone’s advertised developer port. You can try on cellular; if iOS will not open the service, join Wi-Fi and retry.").font(.caption).foregroundStyle(.secondary)
                    }.disabled(locked)
                }
                Section {
                    DisclosureGroup(model.device.pairingImported ? "Setup & troubleshooting" : "First-time setup") {
                        instruction("1", "Enable Developer Mode", "Settings → Privacy & Security → Developer Mode. Restart and confirm if asked.")
                        instruction("2", "Allow network connections", "Connect to the Mac by USB. In Finder → your iPhone → General, enable Show this iPhone when on Wi-Fi, then Apply. This enables the phone’s developer network service.")
                        instruction("3", "Import your pairing file", "Run the supplied make-pairing.sh once on the Mac. AirDrop its .plist to this iPhone and import it here. Keep this private device credential secure.")
                        instruction("4", "Connect LocalDevVPN", "Enable its local tunnel, then return here and tap Connect. Keep it enabled during playback and restoration. No Mac is needed after setup.")
                        Link("LocalDevVPN setup reference", destination: URL(string: "https://github.com/StikDebug/StikDebug#requirements")!)
                        Text("If a fresh connection fails on cellular, connect to Wi-Fi and retry. Automatic port discovery needs Local Network permission. An iOS update or reset may require a new pairing file.").font(.caption).foregroundStyle(.secondary)
                    }
                    if model.device.pairingImported {
                        Button("Replace pairing file") { importShown = true }.disabled(locked)
                    }
                }
                Section {
                    DisclosureGroup("Playback & recovery") {
                        Text(model.background.status).font(.subheadline)
                        Text("Allow location access when you start on-device playback to support switching apps. Preview pauses when hidden. iOS may interrupt background playback after force quit, reboot, signing expiry or VPN loss.").font(.caption).foregroundStyle(.secondary)
                        Text("Use Restore real location when finished. If restoration cannot be confirmed, keep LocalDevVPN on and retry; restart the iPhone if needed and verify in Maps.").font(.caption).foregroundStyle(.secondary)
                        Text("Other apps may detect Apple’s simulated-location flag. Strava recording compatibility is unverified.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    LabeledContent("RoutePilot", value: version)
                    if let expiration = SigningInfo.expirationDate {
                        LabeledContent("Signing expires", value: expiration.formatted(date: .abbreviated, time: .omitted))
                        Text("Refresh the app with your installer before this date to keep it available.").font(.caption).foregroundStyle(.secondary)
                    }
                    NavigationLink("Open-source licenses") { LicenseView() }
                } footer: {
                    Text("Maps and new routes use Apple Maps. GPX and drafts stay on this iPhone. No RoutePilot account or Mac server is required.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("iPhone connection").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismissKeyboard(); dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { dismissKeyboard() } }
            }
            .fileImporter(isPresented: $importShown, allowedContentTypes: [.propertyList, .data], allowsMultipleSelection: false) { result in
                do {
                    if let url = try result.get().first { try model.device.importPairing(url); localError = nil }
                } catch {
                    if (error as NSError).code != NSUserCancelledError { localError = error.localizedDescription }
                }
            }
        }
    }

    private var connectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label(model.device.isBusy ? model.device.connectionStage.title : model.device.isConnected ? "iPhone connected" : model.device.lastError != nil ? "Connection needs attention" : model.device.pairingImported ? "Ready to connect" : "One-time setup", systemImage: model.device.isConnected ? "checkmark.circle.fill" : "iphone")
                    .font(.headline)
                Text(model.device.isConnected ? "Return to your route and choose Start on iPhone." : model.device.pairingImported ? "Enable LocalDevVPN, then connect. RoutePilot finds the developer port for you." : "Import this iPhone’s RPPairing file, then enable LocalDevVPN.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
            if !model.device.pairingImported {
                Button("Import pairing file", systemImage: "doc.badge.plus") { importShown = true }.disabled(locked)
            }
            if model.recoveryRequired || model.device.recoveryRequired {
                Button { Task { await model.stop() } } label: {
                    Label(model.restoring ? "Restoring…" : "Restore real location", systemImage: "location.circle").frame(maxWidth: .infinity, minHeight: 28)
                }.buttonStyle(.borderedProminent).disabled(!model.canStop)
            } else if model.device.isBusy {
                HStack { ProgressView(); Text("Connecting…"); Spacer(); Button("Cancel") { model.device.cancelConnect() } }
            } else if model.device.isConnected {
                Button("Disconnect", role: .destructive) { Task { await model.device.disconnect() } }.disabled(model.active || model.starting)
            } else {
                Button(action: connect) {
                    Label("Connect", systemImage: "link").frame(maxWidth: .infinity, minHeight: 28)
                }.buttonStyle(.borderedProminent)
                    .disabled(!model.device.pairingImported || !model.device.availableOnDevice || model.active || model.starting)
                    .accessibilityIdentifier("connectDevice")
            }
            if let localError { Label(localError, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red) }
            if !model.device.availableOnDevice {
                Text("Developer simulation needs a physical iPhone. Preview and GPX work in Simulator.").font(.caption).foregroundStyle(.secondary)
            }
        } footer: {
            Text("Connecting applies no location. If needed, the first connection downloads about 16 MB of verified developer support files.")
        }
    }

    private var statusSection: some View {
        Section("Connection status") {
            if model.device.isBusy, let started = attemptStarted {
                TimelineView(.periodic(from: started, by: 1)) { context in
                    Text("\(Int(max(0, context.date.timeIntervalSince(started)))) s elapsed").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Label(model.device.status, systemImage: model.device.lastError == nil ? "info.circle" : "exclamationmark.triangle")
                .font(.subheadline).accessibilityIdentifier("deviceStatus")
            if model.device.lastError != nil {
                Button("Open iPhone Settings", systemImage: "gear") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
            }
            if let endpoint = model.device.selectedEndpoint { LabeledContent("Endpoint", value: endpoint).font(.caption).monospacedDigit() }
            DisclosureGroup("Connection details") {
                ForEach(Array(model.device.progress.enumerated()), id: \.offset) { _, text in Text(text).font(.caption).foregroundStyle(.secondary) }
                if let technical = model.device.lastTechnicalError { Text(technical).font(.system(.caption2, design: .monospaced)).textSelection(.enabled) }
                Button(copied ? "Copied" : "Copy diagnostics", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = (["RoutePilot \(version)", model.device.status] + model.device.progress + [model.device.lastTechnicalError].compactMap { $0 }).joined(separator: "\n")
                    copied = true
                }
            }
        }
    }

    private func connect() {
        dismissKeyboard()
        let port: UInt16?
        if automaticPort { port = nil } else {
            guard let value = UInt16(portText.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else { localError = "Enter a port from 1 to 65535."; return }
            port = value
        }
        localError = nil; copied = false; attemptStarted = Date()
        Task {
            do { try await model.device.connect(host: hostText.trimmingCharacters(in: .whitespacesAndNewlines), port: port) }
            catch is CancellationError { }
            catch { if model.device.lastError == nil { localError = error.localizedDescription } }
        }
    }

    private func instruction(_ number: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text("\(number). \(title)").font(.subheadline.bold()); Text(text).font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 3)
    }
}

struct LicenseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(["RoutePilot-LICENSE", "LocSim-LICENSE", "idevice-LICENSE", "IDevice-THIRD-PARTY-LICENSES"], id: \.self) { name in
                    if let url = Bundle.main.url(forResource: name, withExtension: name == "IDevice-THIRD-PARTY-LICENSES" ? "md" : "txt"), let text = try? String(contentsOf: url, encoding: .utf8) {
                        Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                }
            }.padding()
        }.navigationTitle("Licenses")
    }
}
