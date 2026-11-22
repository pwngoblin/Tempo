import Foundation

/// Shared container identifiers. Must match the entitlements in project.yml.
public enum AppGroup {
    /// iOS/watchOS use the plain `group.…` id. On macOS a sandboxed app is only granted a group that is prefixed with the
    /// signing team (`<TEAM>.group.…`; a plain `group.…` id needs a provisioning-profile entitlement Xcode doesn't add), so
    /// the Mac targets carry the expanded id in Info.plist (`TempoAppGroup`, set from `$(TeamIdentifierPrefix)`).
    public static let identifier: String = {
        if let v = Bundle.main.object(forInfoDictionaryKey: "TempoAppGroup") as? String, !v.isEmpty, !v.contains("$(") { return v }
        return "group.com.local.tempo"
    }()
    public static let urlScheme = "tempo"

    /// Defaults shared between the app and its widget extensions on one device.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
