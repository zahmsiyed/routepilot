// Adapted from LocSim 359e423824d8c236a343c871ba696ba08fd3bec1 (MIT).
// Copyright (c) 2026 rockykln. See ios/Vendor/LocSim-LICENSE.txt.
public enum DDIMethod: String, Sendable {
    case cryptex
    case personalized

    /// iOS 26.4 and later install the DDI as a cryptex through cryptexd.
    public static func method(major: Int, minor: Int) -> DDIMethod {
        major > 26 || (major == 26 && minor >= 4) ? .cryptex : .personalized
    }

    public var folder: String {
        switch self {
        case .cryptex: return "Xcode_iOS_DDI_Cryptex"
        case .personalized: return "Xcode_iOS_DDI_Personalized"
        }
    }

    /// File names with their SHA-256 at the pinned commit.
    public var files: [(name: String, sha256: String)] {
        switch self {
        case .cryptex:
            return [
                ("BuildManifest.plist", "27385d7582b03b36bb3104e22b520aee0c47d72fecb4e8ecfe12ef5d966c7012"),
                ("Image.dmg", "873097f695a8b9734e2abc54f795a8874d40ff6fd11208ecb01ef29534c7c176"),
                ("Image.dmg.trustcache", "f7f21986074eee03a215aca16ecfc78d6bf183600d8a0d2fb691f9896782e6f0"),
                ("Image.dmg.cryptex_info", "edf49aef55aacc063d4d7be05b713bb545ce2993b3f62bcc15eccd75e610ee6c"),
                ("Image.dmg.root_hash", "3543fad2805b88119695c417e12679380b3b5a2742994bbcc839c8e2de5d7302"),
            ]
        case .personalized:
            return [
                ("BuildManifest.plist", "8edd4a2f4f4ef1fbd7bfe49785d8badc673d1395d1d94d85b132ca8ab5ecaf54"),
                ("Image.dmg", "05fd807da5e19f030fa4941f24800c965c6c77982ab572dd5d1ef778fb69f9ca"),
                ("Image.dmg.trustcache", "36af60889ff5a737874a26daeb8e1a0139ebfebec6ec2e4d8f6a3c1bf1dce35c"),
            ]
        }
    }
}
