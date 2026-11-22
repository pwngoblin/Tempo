import Foundation

/// Shared container identifiers. Must match the entitlements in project.yml.
public enum AppGroup {
    public static let identifier = "group.com.local.tempo"
    public static let urlScheme = "tempo"

    /// Defaults shared between the app and its widget extensions on one device.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
