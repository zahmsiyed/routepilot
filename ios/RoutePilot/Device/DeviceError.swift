// Adapted from LocSim 359e423824d8c236a343c871ba696ba08fd3bec1 (MIT).
// Copyright (c) 2026 rockykln. See ios/Vendor/LocSim-LICENSE.txt.
import Foundation

/// Technical error from the device layer. `message` is meant for the log;
/// `AppError` turns it into what the user sees.
struct DeviceError: LocalizedError {
    enum Kind {
        case pairingMissing
        case pairingInvalid
        case pairingLockdown
        /// The device's pairing service resets the connection instead of answering.
        case pairingRefused
        case localTunnel
        case otherVPN
        case localNetwork
        case tunnel
        case notConnected
        case ddiQuery
        case ddiConsent
        case ddiDownload
        case ddiInstall
        case locationService
        case setLocation
        case clearLocation
        case other
    }

    let kind: Kind
    let message: String
    /// idevice's error code and sub code, when the error came from the library.
    let code: Int32?
    let subCode: Int32?

    init(_ kind: Kind, _ message: String, code: Int32? = nil, subCode: Int32? = nil) {
        self.kind = kind
        self.message = message
        self.code = code
        self.subCode = subCode
    }

    var errorDescription: String? { message }
}
