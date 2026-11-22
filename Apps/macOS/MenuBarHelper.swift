import AppKit
import ServiceManagement

/// Controls the separate menu-bar helper app embedded at Contents/Library/LoginItems/TempoMenuBar.app.
/// The helper is its own process, so quitting the main app does not remove the menu-bar item.
@MainActor enum MenuBarHelper {
    static let bundleID = "com.local.tempo.menubar"
    static var service: SMAppService { .loginItem(identifier: bundleID) }

    static var url: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/TempoMenuBar.app") }
    static var running: [NSRunningApplication] { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) }
    static var isRunning: Bool { !running.isEmpty }

    /// Start the helper if the user wants a menu-bar item and it isn't running (works even when unsigned).
    static func ensureRunning() {
        guard PrefsStore.shared.values.menuBarEnabled, !isRunning, FileManager.default.fileExists(atPath: url.path) else { return }
        let cfg = NSWorkspace.OpenConfiguration(); cfg.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in }
    }

    static func stop() { running.forEach { $0.terminate() } }

    /// Apply the "Show in menu bar" preference.
    static func apply(enabled: Bool) { enabled ? ensureRunning() : stop() }
}
