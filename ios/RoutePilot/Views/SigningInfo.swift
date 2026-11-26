import Foundation

/// Read only the expiry date from this app's embedded development profile.
/// No profile data or credentials leave the bundle.
enum SigningInfo {
    static let expirationDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 4_000_000,
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let profile = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return nil }
        return profile["ExpirationDate"] as? Date
    }()
}
