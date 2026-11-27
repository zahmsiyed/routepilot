import Foundation
import CryptoKit

#if DEVICE_CONNECTION_TESTS
// The test build excludes native FFI entirely. A live transport would fail rather
// than contact a device if an injection boundary regressed.
final class DeviceLink: @unchecked Sendable {
    var isOpen: Bool { false }
    var hasTunnel: Bool { false }
    var isStuck: Bool { false }
    var hasPendingOperation: Bool { false }
    func openTunnel(_ config: LinkConfig) async throws { throw failure }
    func isDDIMounted() async throws -> Bool { throw failure }
    func mountDDI(from directory: URL, method: DDIMethod) async throws { throw failure }
    func openLocation() async throws { throw failure }
    func set(latitude: Double, longitude: Double) async throws { throw failure }
    func clear() async throws { throw failure }
    func close() async { }
    func release() { }
    private var failure: Error { NSError(domain: "TestsMustNotUseLiveTransport", code: 1) }
}
#endif

final class FakeTransport: DeviceTransport, @unchecked Sendable {
    let lock = NSLock()
    var events: [String] = []
    var isOpen = false
    var hasTunnel = false
    var isStuck = false
    var hasPendingOperation = false
    var tunnelError: Error?
    var pendingOnTunnelFailure = false
    var writeError: Error?
    var mounted = true
    func openTunnel(_ config: LinkConfig) async throws { events.append("open:\(config.port)"); if let tunnelError { if pendingOnTunnelFailure { isStuck = true; hasPendingOperation = true }; throw tunnelError }; hasTunnel = true }
    func isDDIMounted() async throws -> Bool { events.append("ddi"); return mounted }
    func mountDDI(from directory: URL, method: DDIMethod) async throws { events.append("mount") }
    func openLocation() async throws { events.append("location"); isOpen = true }
    func set(latitude: Double, longitude: Double) async throws { events.append("set"); if let writeError { throw writeError } }
    func clear() async throws { events.append("clear"); isOpen = false }
    func close() async { events.append("close"); isOpen = false; hasTunnel = false }
    func release() { events.append("release") }
}

final class LockedTestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}

@main struct ConnectionTests {
    @MainActor static func main() async throws {
        var count = 0
        var suites: [String] = []
        defer { for name in suites { UserDefaults.standard.removePersistentDomain(forName: name) } }
        func check(_ value: @autoclosure () -> Bool, _ message: String) throws {
            if !value() { throw NSError(domain: "ConnectionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func expectFailure(_ body: () async throws -> Void) async throws {
            do { try await body() } catch { return }
            throw NSError(domain: "ConnectionTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected a connection failure"])
        }
        func defaults(_ number: Int) -> UserDefaults {
            let name = "routepilot.connection.tests.\(UUID().uuidString).\(number)"
            suites.append(name)
            let d = UserDefaults(suiteName: name)!; d.removePersistentDomain(forName: name); return d
        }
        func environment(_ link: FakeTransport, _ d: UserDefaults) -> DeviceConnectionEnvironment {
            DeviceConnectionEnvironment(supportsDeviceConnection: true, defaults: d, makeTransport: { link }, pairingExists: { true }, loadPairing: { Data([1]) }, discover: { PairingDiscoveryResult() }, probe: { _,_,_ in }, prepareDDI: { _,_ in URL(fileURLWithPath: "/tmp/fake-ddi") })
        }
        do {
            let fake = FakeTransport(), d = defaults(1)
            d.set("10.7.0.1", forKey: "device.lastHost"); d.set(49159, forKey: "device.lastPort")
            var discoveryCalls = 0, probes: [UInt16] = []
            var env = environment(fake,d)
            env.discover = { discoveryCalls += 1; return PairingDiscoveryResult() }
            env.probe = { _,port,_ in probes.append(port) }
            let device = DeviceConnection(environment: env)
            try await device.connect()
            try check(device.isConnected && !device.isBusy, "saved endpoint connects")
            try check(discoveryCalls == 0 && probes == [49159], "cellular saved endpoint bypasses Bonjour")
            try check(fake.events == ["open:49159","ddi","location"], "connect sends no coordinates or duplicate handshakes")
            count += 1
        }
        do {
            let fake = FakeTransport(), d = defaults(2)
            var probes: [UInt16] = [], env = environment(fake,d)
            env.discover = { PairingDiscoveryResult(services: [.init(port: 50000,isThisDevice: false),.init(port: 49153,isThisDevice: true)]) }
            env.probe = { _,port,_ in probes.append(port); if port == 49152 { throw DeviceError(.localTunnel,"closed") } }
            let device = DeviceConnection(environment: env); try await device.connect()
            try check(probes == [49152,49153], "only local advertisements are probed")
            try check(fake.events.filter{$0.hasPrefix("open:")} == ["open:49153"], "one authenticated open after discovery")
            count += 1
        }
        do {
            let fake = FakeTransport(); var discovers = 0, env = environment(fake,defaults(3))
            env.discover = { discovers += 1; return PairingDiscoveryResult() }
            env.probe = { _,_,_ in throw DeviceError(.localTunnel,"manual socket closed") }
            let device = DeviceConnection(environment: env)
            try await expectFailure { try await device.connect(port: 49155) }
            try check(discovers == 0 && !fake.events.contains{$0.hasPrefix("open:")}, "manual override never discovers or handshakes after a failed probe")
            try check(device.lastTechnicalError?.contains("manual socket closed") == true && device.lastError?.contains("LocalDevVPN") == true, "actionable and technical errors remain separate")
            count += 1
        }
        do {
            let fake = FakeTransport(); fake.tunnelError = DeviceError(.tunnel,"authentication failed (103)")
            var probes = 0, env = environment(fake,defaults(4)); env.probe = { _,_,_ in probes += 1 }
            let device = DeviceConnection(environment: env)
            try await expectFailure { try await device.connect() }
            try check(probes == 1 && fake.events.filter{$0.hasPrefix("open:")}.count == 1, "authentication failures never retry other ports")
            try check(device.lastTechnicalError == "authentication failed (103)" && device.connectionStage == .failed, "raw transport error retained")
            count += 1
        }
        do {
            let fake = FakeTransport(); var env = environment(fake,defaults(5))
            env.probe = { _,_,_ in throw DeviceError(.localTunnel,"closed") }
            env.discover = { try await Task.sleep(for:.seconds(5)); return PairingDiscoveryResult() }
            let device = DeviceConnection(environment: env)
            let task = Task { @MainActor in try await device.connect() }
            while device.connectionStage != .discovering { await Task.yield() }
            let begin = ContinuousClock.now
            device.cancelConnect()
            do { try await task.value } catch { }
            try check(begin.duration(to:.now) < .seconds(1), "Cancel returns promptly")
            try check(!device.isBusy && device.connectionStage == .cancelled && device.lastError == nil, "cancellation is not an error or indefinite busy state")
            try check(!fake.events.contains{$0.hasPrefix("open:")}, "cancelled discovery never starts developer authentication")
            count += 1
        }
        do {
            let old = FakeTransport(), replacement = FakeTransport(), d = defaults(6)
            old.tunnelError = DeviceError(.notConnected,"native timeout"); old.isStuck = false
            var factories = 0, env = environment(old,d)
            env.makeTransport = { factories += 1; return factories == 1 ? old : replacement }
            let device = DeviceConnection(environment: env)
            // First timeout still has an uncancellable native call pending.
            old.pendingOnTunnelFailure = true
            try await expectFailure { try await device.connect() }
            try await expectFailure { try await device.connect() }
            try check(factories == 1 && old.events.filter{$0.hasPrefix("open:")}.count == 1, "pending native call quarantines old transport")
            old.hasPendingOperation = false
            try await device.connect()
            try check(factories == 2 && device.isConnected, "settled transport can be replaced safely")
            count += 1
        }
        do {
            let fake = FakeTransport(), d = defaults(7)
            d.set(true,forKey:"device.locationMayBeSimulated"); d.set(49154,forKey:"device.lastPort")
            var probes:[UInt16] = [], env = environment(fake,d)
            env.discover = { PairingDiscoveryResult(services:[.init(port:49155,isThisDevice:true)]) }
            env.probe = { _,port,_ in probes.append(port); if port == 49154 { throw DeviceError(.localTunnel,"old port") } }
            let device = DeviceConnection(environment:env)
            try await device.clear()
            try check(probes == [49154,49155] && fake.events.last == "clear", "Restore discovers a changed local port")
            try check(!device.recoveryRequired && !d.bool(forKey:"device.locationMayBeSimulated"), "only confirmed Clear removes durable recovery state")
            count += 1
        }
        do {
            let fake = FakeTransport(), d = defaults(8)
            let env = environment(fake,d)
            let device = DeviceConnection(environment:env); try await device.connect()
            fake.writeError = DeviceError(.setLocation,"unconfirmed write")
            try await expectFailure { try await device.set(latitude:1,longitude:2) }
            try check(device.recoveryRequired && !device.isConnected && d.bool(forKey:"device.locationMayBeSimulated"), "uncertain write durably requires restore")
            count += 1
        }
        do {
            let fake = FakeTransport(); var hostSeen = ""
            var env = environment(fake,defaults(9)); env.probe = { host,_,_ in hostSeen = host }
            let device = DeviceConnection(environment:env)
            try await device.connect(host:" 10.7.0.1/32 ",port:49152)
            try check(hostSeen == "10.7.0.1" && device.selectedEndpoint == "10.7.0.1:49152", "IPv4 /32 input normalizes before socket and handshake")
            count += 1
        }
        do {
            let fake = FakeTransport(); var probes = 0, env = environment(fake,defaults(10))
            env.probe = { _,_,_ in probes += 1 }
            let device = DeviceConnection(environment:env)
            for invalid in ["", "0.0.0.0", "10.7.0.1/24", "example.com", "10.7.0.1:49152"] {
                try await expectFailure { try await device.connect(host:invalid) }
            }
            try await expectFailure { try await device.connect(port:0) }
            try check(probes == 0 && fake.events.isEmpty && !device.isBusy, "invalid connection input is rejected before any operation")
            count += 1
        }
        do {
            let fake = FakeTransport(); var env = environment(fake,defaults(11))
            env.probe = { _,_,_ in throw DeviceError(.localNetwork,"permission denied") }
            let device = DeviceConnection(environment:env)
            try await expectFailure { try await device.connect() }
            try check(device.lastError?.contains("Local Network") == true && device.lastTechnicalError == "permission denied", "permission errors have a specific diagnosis")
            try check(!fake.events.contains{$0.hasPrefix("open:")}, "permission denial never reaches developer authentication")
            count += 1
        }
        do {
            let fake = FakeTransport(); var probes = 0, env = environment(fake,defaults(12))
            env.probe = { _,_,_ in probes += 1; throw DeviceError(.localTunnel,"closed") }
            env.discover = { PairingDiscoveryResult(services:(50000...50020).map{.init(port:UInt16($0),isThisDevice:true)}) }
            let device = DeviceConnection(environment:env)
            try await expectFailure { try await device.connect() }
            try check(probes == 4, "automatic reachability checks have a fixed total candidate limit")
            count += 1
        }
        do {
            let fake = FakeTransport(), d = defaults(17)
            d.set(53233, forKey: "device.lastPort")
            var timeouts: [UInt16: TimeInterval] = [:], env = environment(fake, d)
            env.discover = { PairingDiscoveryResult(services: [.init(port: 63501, isThisDevice: true)]) }
            env.probe = { _, port, timeout in
                timeouts[port] = timeout
                throw DeviceError(.localTunnel, "timeout on \(port)")
            }
            let device = DeviceConnection(environment: env)
            try await expectFailure { try await device.connect() }
            let detail = device.lastTechnicalError ?? ""
            try check([53233, 63501, 49152].allSatisfy { detail.contains("timeout on \($0)") }, "failure preserves each candidate reason, including the advertised port")
            try check(timeouts[63501] == 3 && timeouts[53233] == 1.5 && timeouts[49152] == 1.5, "advertised port receives a longer bounded TCP deadline")
            try check(device.progress.contains { $0.contains("advertises developer port 63501") }, "discovered service is distinguished from TCP reachability")
            try check(detail.contains("Pairing authentication was not attempted") && !fake.events.contains { $0.hasPrefix("open:") }, "unreachable sockets never authenticate or mutate device services")
            count += 1
        }
        do {
            let fake = FakeTransport(); var probes: [UInt16] = [], env = environment(fake, defaults(18))
            env.discover = { PairingDiscoveryResult(services: [.init(port: 63501, isThisDevice: true)]) }
            env.probe = { _, port, _ in
                probes.append(port)
                if port == 49152 { throw DeviceError(.localTunnel, "old port") }
                throw DeviceError(.localNetwork, "local network denied by iOS")
            }
            let device = DeviceConnection(environment: env)
            try await expectFailure { try await device.connect() }
            try check(probes == [49152, 63501] && device.lastTechnicalError == "local network denied by iOS", "permission denial during discovered-port probing stops fallback checks")
            try check(device.lastError?.contains("Local Network") == true && !fake.events.contains { $0.hasPrefix("open:") }, "permission denial remains actionable and never reaches native authentication")
            count += 1
        }
        do {
            let fake = FakeTransport(), d = defaults(19)
            d.set(63501, forKey: "device.lastPort")
            var probes: [(UInt16, TimeInterval)] = [], env = environment(fake, d)
            env.discover = { PairingDiscoveryResult(services: [.init(port: 63501, isThisDevice: true), .init(port: 63501, isThisDevice: true)]) }
            env.probe = { _, port, timeout in
                probes.append((port, timeout))
                if timeout < 3 { throw DeviceError(.localTunnel, "VPN still warming") }
            }
            let device = DeviceConnection(environment: env)
            try await device.connect()
            try check(probes.map { $0.0 } == [63501, 63501] && probes.map { $0.1 } == [1.5, 3], "fresh discovery confirms one longer recheck of a previously failed saved port")
            try check(device.isConnected && fake.events.filter { $0.hasPrefix("open:") } == ["open:63501"], "a warming TCP route still starts only one authenticated handshake")
            count += 1
        }
        do {
            let fake = FakeTransport(); fake.mounted = false
            var env = environment(fake,defaults(13))
            env.prepareDDI = { _,_ in try await Task.sleep(for:.seconds(5)); return URL(fileURLWithPath:"/tmp/fake-ddi") }
            let device = DeviceConnection(environment:env)
            let task = Task { @MainActor in try await device.connect() }
            while device.connectionStage != .downloadingDDI { await Task.yield() }
            device.cancelConnect()
            try await expectFailure { try await task.value }
            try check(!device.isBusy && device.connectionStage == .cancelled && !fake.events.contains("mount"), "Cancel during support download prevents mounting or opening location")
            count += 1
        }
        do {
            let gate = ResumeGate()
            try check(gate.claim() && !gate.begin(), "cancelled queued native operations never start")
            let running = ResumeGate()
            try check(running.begin() && running.didBegin && running.claim() && !running.claim(), "running operation cancellation has exactly one completion")
            let raced = ResumeGate(), winners = LockedTestCounter()
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<100 { group.addTask { if raced.claim() { winners.increment() } } }
                await group.waitForAll()
            }
            try check(winners.value == 1, "timeout, cancellation, and completion cannot resume a native continuation twice")
            count += 1
        }
        do {
            let cancellation = NativeOperationCancellation()
            var callbacks = 0
            cancellation.cancel()
            cancellation.install { callbacks += 1 }
            cancellation.cancel()
            try check(callbacks == 1, "cancellation before handler registration is not lost or repeated")
            let completed = NativeOperationCancellation()
            completed.install { callbacks += 1 }; completed.clear(); completed.cancel()
            try check(callbacks == 1, "finished native calls release cancellation handlers")
            count += 1
        }
        do {
            let key = Curve25519.Signing.PrivateKey()
            let record: [String:Any] = ["private_key":key.rawRepresentation,"public_key":key.publicKey.rawRepresentation,"identifier":"routepilot-unit-test"]
            let valid = try PropertyListSerialization.data(fromPropertyList:record,format:.xml,options:0)
            try PairingIdentity.validate(valid)
            var bad = record; bad["public_key"] = Data(repeating:0,count:32)
            let mismatched = try PropertyListSerialization.data(fromPropertyList:bad,format:.xml,options:0)
            var rejected = 0
            for data in [mismatched,Data(repeating:0,count:65537),Data("not a plist".utf8)] {
                do { try PairingIdentity.validate(data) } catch { rejected += 1 }
            }
            try check(rejected == 3, "pairing keys, property lists, and size limits are validated before storage or authentication")
            count += 1
        }
        print("Device connection orchestration: \(count) scenarios passed; no physical device or coordinates used.")
    }
}
