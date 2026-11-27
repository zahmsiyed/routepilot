import Combine
import CryptoKit
import Darwin
import Foundation

enum DeviceConnectionStage: String {
    case idle = "Ready to connect"
    case discovering = "Finding this iPhone"
    case checkingSocket = "Checking local tunnel"
    case openingTunnel = "Opening developer tunnel"
    case checkingDDI = "Checking developer support"
    case downloadingDDI = "Downloading developer support"
    case mountingDDI = "Mounting developer support"
    case openingLocation = "Opening location service"
    case connected = "Connected"
    case restoring = "Restoring real location"
    case cancelled = "Connection cancelled"
    case failed = "Connection needs attention"
    var title: String { rawValue }
}

/// Coordinates one on-device connection attempt. Reachability probes may try
/// several local ports; authenticated developer setup is attempted exactly once.
@MainActor
final class DeviceConnection: ObservableObject {
    @Published private(set) var status = "Import this iPhone’s RPPairing file to begin."
    @Published private(set) var isConnected = false
    @Published private(set) var isBusy = false
    @Published private(set) var progress: [String] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastTechnicalError: String?
    @Published private(set) var connectionStage = DeviceConnectionStage.idle
    @Published private(set) var selectedEndpoint: String?
    @Published private(set) var pairingImported: Bool
    @Published private(set) var recoveryRequired: Bool
    let availableOnDevice: Bool

    private let environment: DeviceConnectionEnvironment
    private var link: any DeviceTransport
    private var connectionTask: Task<Void, Error>?
    private var operationRevision = UUID()
    private var mayBeSimulated: Bool {
        didSet { environment.defaults.set(mayBeSimulated, forKey: "device.locationMayBeSimulated") }
    }
    private var connectedHost: String
    private var connectedPort: UInt16

    init(environment: DeviceConnectionEnvironment? = nil) {
        let environment = environment ?? .live
        self.environment = environment
        availableOnDevice = environment.supportsDeviceConnection
        pairingImported = environment.pairingExists()
        let recovery = environment.defaults.bool(forKey: "device.locationMayBeSimulated")
        mayBeSimulated = recovery; recoveryRequired = recovery
        connectedHost = Self.normalizedHost(environment.defaults.string(forKey: "device.lastHost") ?? "10.7.0.1")
        connectedPort = UInt16(exactly: environment.defaults.integer(forKey: "device.lastPort")).flatMap { $0 > 0 ? $0 : nil } ?? 49152
        link = environment.makeTransport()
        if recovery { status = "A previous device session may still need restoration. Enable LocalDevVPN and tap Restore real location." }
    }

    func importPairing(_ url: URL) throws {
        guard !isBusy, !isConnected, !mayBeSimulated else { throw DeviceError(.pairingInvalid, "Restore and disconnect before replacing the pairing file.") }
        try PairingIdentity.importFile(url)
        pairingImported = true; lastError = nil; lastTechnicalError = nil
        status = "Pairing file imported. Enable LocalDevVPN, then connect."
    }

    func removePairing() throws {
        guard !isBusy, !isConnected, !mayBeSimulated else { throw DeviceError(.pairingInvalid, "Restore and disconnect before removing the pairing file.") }
        try PairingIdentity.remove()
        pairingImported = false; status = "Pairing file removed."
    }

    /// nil uses discovery; a supplied port is a strict manual override.
    func connect(host: String = "10.7.0.1", port: UInt16? = nil) async throws {
        guard availableOnDevice else { throw DeviceError(.notConnected, "Use a physical iPhone for the developer connection. Preview works in Simulator.") }
        guard !isBusy else { throw DeviceError(.notConnected, "A device operation is already in progress.") }
        guard !mayBeSimulated else { throw DeviceError(.notConnected, "Restore real location before starting a new developer connection.") }
        if isConnected, link.isOpen { return }
        let host = Self.normalizedHost(host)
        try Self.validate(host: host, port: port)
        isBusy = true; operationRevision = UUID(); progress = []
        lastError = nil; lastTechnicalError = nil; selectedEndpoint = nil
        let task = Task { try await self.performConnect(host: host, port: port) }
        connectionTask = task
        defer { connectionTask = nil; isBusy = false }
        try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }

    func cancelConnect() {
        guard connectionTask != nil else { return }
        status = "Cancelling connection…"
        connectionTask?.cancel()
    }

    private func performConnect(host: String, port: UInt16?) async throws {
        do {
            try await prepareTransport()
            let pairing = try environment.loadPairing()
            let selected = try await selectPort(host: host, manual: port)
            try await open(host: host, port: selected, pairing: pairing)
            try Task.checkCancellation()
            isConnected = true; recoveryRequired = false
            stage(.connected, "Connected. Starting a route will apply its location.")
        } catch {
            isConnected = false
            if error is CancellationError || Task.isCancelled {
                // close() respects cancellation, so use uncancellable queued cleanup
                // here. It never runs ahead of the native operation it releases.
                link.release()
                connectionStage = .cancelled; lastError = nil; lastTechnicalError = nil
                log(link.hasPendingOperation ? "Connection cancelled. A command already in progress must finish before reconnecting." : "Connection cancelled. No route was started.")
                throw CancellationError()
            }
            if link.hasPendingOperation { link.release() } else { await link.close() }
            record(error)
            throw error
        }
    }

    private func selectPort(host: String, manual: UInt16?) async throws -> UInt16 {
        var attempted = Set<UInt16>()
        var failures: [String] = []
        func probe(_ port: UInt16, timeout: TimeInterval = 1.5) async throws -> Bool {
            attempted.insert(port)
            try Task.checkCancellation()
            stage(.checkingSocket, "Checking local tunnel at \(host):\(port)…")
            do {
                try await environment.probe(host, port, timeout)
                try Task.checkCancellation()
                selectedEndpoint = "\(host):\(port)"
                return true
            } catch is CancellationError { throw CancellationError() }
            catch {
                if (error as? DeviceError)?.kind == .localNetwork { throw error }
                let detail = "\(host):\(port): \(error.localizedDescription)"
                failures.append(detail)
                log("TCP check failed at \(detail)")
                return false
            }
        }
        // A saved endpoint is quickest and may remain reachable on cellular.
        // No Wi-Fi requirement is imposed before trying the local socket.
        let first = manual ?? (host == connectedHost ? connectedPort : 49152)
        if try await probe(first) { return first }
        if manual == nil {
            stage(.discovering, "Finding this iPhone’s advertised developer port…")
            let discovery = try await environment.discover()
            try Task.checkCancellation()
            if discovery.searchFailed { log("Bonjour was unavailable. Allow Local Network access in Settings and confirm wireless developer access was enabled during USB pairing. Saved local ports can still work without Wi-Fi.") }
            let ownPorts = discovery.services.filter(\.isThisDevice).map(\.port)
            let advertisedPorts = Set(ownPorts)
            if ownPorts.isEmpty { log("No matching advertisement from this iPhone. Checking the default local port.") }
            else {
                let ports = advertisedPorts.sorted().map(String.init).joined(separator: ", ")
                log("This iPhone advertises developer port\(advertisedPorts.count == 1 ? "" : "s") \(ports). An advertisement does not confirm that the VPN can reach it.")
            }
            var seen = attempted
            let candidates = (ownPorts + [49152]).filter { $0 > 0 && seen.insert($0).inserted }.prefix(3)
            for candidate in candidates {
                // Give the current advertised service time for a TCP retransmit
                // while keeping stale/default candidates quick and cancellable.
                if try await probe(candidate, timeout: advertisedPorts.contains(candidate) ? 3 : 1.5) { return candidate }
            }
        }
        throw DeviceError(.localTunnel, "No developer TCP connection succeeded. Pairing authentication was not attempted.\n" + failures.joined(separator: "\n"))
    }

    func set(latitude: Double, longitude: Double) async throws {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180 else { throw DeviceError(.setLocation, "Choose a valid latitude and longitude.") }
        guard isConnected, !isBusy, link.isOpen, !link.isStuck else { throw DeviceError(.notConnected, "The developer connection is unavailable. Restore and reconnect.") }
        let revision = operationRevision
        mayBeSimulated = true; recoveryRequired = true
        do {
            try await link.set(latitude: latitude, longitude: longitude)
            guard operationRevision == revision else { throw CancellationError() }
            status = "Applying locations on this iPhone."
        } catch {
            guard operationRevision == revision else { throw CancellationError() }
            isConnected = false; recoveryRequired = true
            record(error, prefix: "Playback stopped. Real location has not been confirmed. ")
            throw error
        }
    }

    func clear() async throws {
        guard !isBusy else { throw DeviceError(.notConnected, "Wait for the current device operation to finish, then restore.") }
        guard availableOnDevice else { return }
        isBusy = true; operationRevision = UUID()
        defer { isBusy = false }
        do {
            if mayBeSimulated, !link.isOpen || link.isStuck {
                stage(.restoring, "Reopening the saved developer connection to restore location…")
                try await prepareTransport()
                let port = try await selectPort(host: connectedHost, manual: nil)
                try await open(host: connectedHost, port: port, pairing: environment.loadPairing())
            }
            stage(.restoring, "Sending the clear-location command…")
            try await link.clear()
            mayBeSimulated = false; recoveryRequired = false; isConnected = false
            lastError = nil; lastTechnicalError = nil; connectionStage = .idle
            log("Restore command succeeded. Verify your real position in Maps.")
        } catch {
            recoveryRequired = mayBeSimulated; isConnected = link.isOpen && !link.isStuck
            record(error, prefix: "Restore could not be confirmed. ")
            throw error
        }
    }

    func disconnect() async {
        guard !isBusy else { return }
        if mayBeSimulated { do { try await clear() } catch { return } }
        else { await link.close(); isConnected = false; connectionStage = .idle; status = "Disconnected." }
    }

    private func prepareTransport() async throws {
        try Task.checkCancellation()
        guard !link.hasPendingOperation else { throw DeviceError(.notConnected, "The previous device command or cleanup is still pending. Wait and retry; restart the iPhone and check Maps if restoration remains unconfirmed.") }
        if link.isStuck {
            await link.close()
            link = environment.makeTransport()
        }
        try Task.checkCancellation()
    }

    private func open(host: String, port: UInt16, pairing: Data) async throws {
        stage(.openingTunnel, "Authenticating this iPhone’s developer tunnel…")
        try Task.checkCancellation()
        try await link.openTunnel(LinkConfig(host: host, port: port, hostname: "RoutePilot", pairing: pairing))
        connectedHost = host; connectedPort = port
        environment.defaults.set(host, forKey: "device.lastHost")
        environment.defaults.set(Int(port), forKey: "device.lastPort")
        stage(.checkingDDI, "Checking Developer Disk Image…")
        try Task.checkCancellation()
        if !(try await link.isDDIMounted()) {
            let method = DDIMethod.current
            stage(.downloadingDDI, "Preparing verified developer support files (first download about 16 MB)…")
            let directory = try await environment.prepareDDI(method) { [weak self] in self?.log($0) }
            try Task.checkCancellation()
            stage(.mountingDDI, "Mounting developer support files; this can take a few minutes…")
            try await link.mountDDI(from: directory, method: method)
        }
        try Task.checkCancellation()
        stage(.openingLocation, "Opening the location simulation service…")
        try await link.openLocation()
    }

    private func stage(_ value: DeviceConnectionStage, _ text: String) { connectionStage = value; log(text) }
    private func log(_ text: String) { status = text; progress.append(text); if progress.count > 60 { progress.removeFirst(progress.count - 60) } }

    private func record(_ error: Error, prefix: String = "") {
        lastTechnicalError = error.localizedDescription
        let hint: String
        switch (error as? DeviceError)?.kind {
        case .pairingMissing, .pairingInvalid, .pairingLockdown, .pairingRefused:
            hint = "Import a fresh RPPairing file for this iPhone, then reconnect."
        case .localNetwork:
            hint = "Allow RoutePilot’s Local Network access in iPhone Settings, then retry."
        case .localTunnel:
            hint = "Open LocalDevVPN and confirm its main screen says Connected. Allow RoutePilot in Settings → Privacy & Security → Local Network. If you are on cellular, join Wi-Fi and retry with the same Device IP and automatic port."
        case .tunnel:
            hint = "The socket responded but developer authentication failed. Check Developer Mode and this iPhone’s pairing file."
        case .ddiDownload:
            hint = "Developer support files could not be downloaded or verified. Check internet access and retry."
        case .ddiInstall, .ddiQuery:
            hint = "Developer support could not be prepared. Keep the iPhone unlocked and check Developer Mode, then retry."
        case .locationService:
            hint = "The developer tunnel opened but its location service did not. Disconnect and reconnect after checking Developer Mode."
        default: hint = error.localizedDescription
        }
        lastError = prefix + hint; connectionStage = .failed; log(lastError!)
    }

    private static func normalizedHost(_ value: String) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.hasSuffix("/32") ? String(value.dropLast(3)) : value
    }

    private static func validate(host: String, port: UInt16?) throws {
        var address = in_addr()
        guard inet_pton(AF_INET, host, &address) == 1, host != "0.0.0.0", host != "255.255.255.255" else { throw DeviceError(.localTunnel, "Enter a numeric IPv4 address for the local tunnel, such as 10.7.0.1.") }
        guard port != 0 else { throw DeviceError(.localTunnel, "Enter a port between 1 and 65535, or use automatic discovery.") }
    }
}

enum PairingIdentity {
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RoutePilot", isDirectory: true).appendingPathComponent("rppairing.plist")
    }
    static var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
    static func load() throws -> Data {
        guard exists else { throw DeviceError(.pairingMissing, "Import this iPhone’s RPPairing file in Setup first.") }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: 65537) ?? Data()
        try validate(data)
        return data
    }
    static func importFile(_ source: URL) throws {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let file = try FileHandle(forReadingFrom: source)
        defer { try? file.close() }
        let data = try file.read(upToCount: 65537) ?? Data()
        try validate(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var saved = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try saved.setResourceValues(values)
    }
    static func validate(_ data: Data) throws {
        guard data.count <= 65536,
              let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw DeviceError(.pairingInvalid, "Choose a valid RPPairing property list smaller than 64 KB.")
        }
        if plist["HostPrivateKey"] != nil { throw DeviceError(.pairingLockdown, "This is a lockdown pairing file. Export an RPPairing file instead.") }
        guard let privateKey = plist["private_key"] as? Data, privateKey.count == 32,
              let publicKey = plist["public_key"] as? Data, publicKey.count == 32,
              let identifier = plist["identifier"] as? String, !identifier.isEmpty, identifier.utf8.count <= 256,
              !identifier.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKey),
              signingKey.publicKey.rawRepresentation == publicKey else {
            throw DeviceError(.pairingInvalid, "The RPPairing identity or signing keys are invalid. Export a fresh pairing file.")
        }
        if let irk = plist["alt_irk"], (irk as? Data)?.count != 16 {
            throw DeviceError(.pairingInvalid, "The RPPairing identity key is invalid. Export a fresh pairing file.")
        }
    }

    static func remove() throws {
        if exists { try FileManager.default.removeItem(at: url) }
    }
}
