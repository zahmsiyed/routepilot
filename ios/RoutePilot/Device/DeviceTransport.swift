import Foundation

struct LinkConfig {
    var host: String
    var port: UInt16
    var hostname: String
    var pairing: Data
}


/// Synchronous native calls are hidden behind an async transport so connection
/// orchestration can be tested without opening a developer service or sending GPS.
protocol DeviceTransport: AnyObject, Sendable {
    var isOpen: Bool { get }
    var hasTunnel: Bool { get }
    var isStuck: Bool { get }
    var hasPendingOperation: Bool { get }
    func openTunnel(_ config: LinkConfig) async throws
    func isDDIMounted() async throws -> Bool
    func mountDDI(from directory: URL, method: DDIMethod) async throws
    func openLocation() async throws
    func set(latitude: Double, longitude: Double) async throws
    func clear() async throws
    func close() async
    func release()
}

extension DeviceLink: DeviceTransport {}

@MainActor
struct DeviceConnectionEnvironment {
    var supportsDeviceConnection: Bool
    var defaults: UserDefaults
    var makeTransport: () -> any DeviceTransport
    var pairingExists: () -> Bool
    var loadPairing: () throws -> Data
    var discover: () async throws -> PairingDiscoveryResult
    var probe: (String, UInt16, TimeInterval) async throws -> Void
    var prepareDDI: (DDIMethod, @escaping (String) -> Void) async throws -> URL

    static var live: Self {
        #if targetEnvironment(simulator)
        let physical = false
        #else
        let physical = true
        #endif
        return Self(supportsDeviceConnection: physical, defaults: .standard,
                    makeTransport: { DeviceLink() }, pairingExists: { PairingIdentity.exists },
                    loadPairing: { try PairingIdentity.load() },
                    discover: { try await LocalPairingDiscovery().browse() },
                    probe: { try await DeveloperSocketProbe.check(host: $0, port: $1, timeout: $2) },
                    prepareDDI: { try await DDIStore.prepare($0, log: $1) })
    }
}
