import SwiftUI
import CalendarCore

/// Closing the window must not quit the app: the menu-bar item (countdown, popover, Join) should keep running.
/// ⌘Q or "Quit" in the popover still quits. Clicking the Dock icon with no window brings the window back.
final class TempoAppDelegate: NSObject, NSApplicationDelegate {
    static var openMain: (() -> Void)?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Self.openMain?() }
        return true
    }
}

@main
struct TempoMacApp: App {
    @NSApplicationDelegateAdaptor(TempoAppDelegate.self) private var delegate
    @State private var manager = EventStoreManager()
    @State private var nav = Navigator()

    var body: some Scene {
        Window("Tempo", id: "main") {
            RootView()
                .environment(manager).environment(nav)
                .tempoAppearance(manager)
                .tempoInterfaceScale()
                .onChange(of: PrefsStore.shared.values.menuBarEnabled) { _, on in MenuBarHelper.apply(enabled: on) }
                .task { MenuBarHelper.ensureRunning(); await manager.requestAccess() }
                .onOpenURL { nav.handle($0, manager: manager) }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in manager.refreshSources() }
                .frame(minWidth: 860, minHeight: 560)
        }
        .commands { TempoCommands(nav: nav, manager: manager) }

        Settings { SettingsView().environment(manager).tempoAppearance(manager) }
    }
}

enum ViewMode: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", month = "Month"
    var id: String { rawValue }
}

@MainActor @Observable
final class Navigator {
    var date = Date()
    var mode: ViewMode = ViewMode(rawValue: PrefsStore.shared.values.defaultViewMac.capitalized) ?? .week
    var showQuickAdd = false
    var settingsRequest = 0   // bumped by tempo://settings; RootView opens the Settings window
    var editor: EditorTarget?

    private let cal = Calendar.tempo

    func shift(_ direction: Int) {
        let unit: Calendar.Component = mode == .day ? .day : mode == .week ? .weekOfYear : .month
        date = cal.date(byAdding: unit, value: direction, to: date) ?? date
    }

    func handle(_ url: URL, manager: EventStoreManager) {
        switch DeepLink(url: url) {
        case .today: date = .now
        case .day(let iso): if let d = DeepLink.date(from: iso) { date = d; mode = .day }
        case .set(let id): manager.setActive(id)
        case .add: showQuickAdd = true
        case .settings: settingsRequest += 1
        case .event(let id):
            let start = cal.startOfDay(for: date)
            if let e = manager.events(from: cal.date(byAdding: .month, value: -1, to: start)!, to: cal.date(byAdding: .month, value: 2, to: start)!)
                .first(where: { $0.eventID == id }) { date = e.start; editor = .edit(e) }
        case nil: break
        }
    }
}

struct TempoCommands: Commands {
    let nav: Navigator
    let manager: EventStoreManager

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Event…") { nav.showQuickAdd = true }.keyboardShortcut("n")
            Button("Quick Add") { nav.showQuickAdd = true }.keyboardShortcut("k")
        }
        CommandGroup(after: .toolbar) {
            Button("Zoom In") { PrefsStore.shared.values.interfaceSize = PrefsStore.shared.values.interfaceSize.larger }.keyboardShortcut("=")
            Button("Zoom Out") { PrefsStore.shared.values.interfaceSize = PrefsStore.shared.values.interfaceSize.smaller }.keyboardShortcut("-")
            Button("Actual Size") { PrefsStore.shared.values.interfaceSize = .standard }.keyboardShortcut("0")
        }
        CommandMenu("Navigate") {
            Button("Today") { nav.date = .now }.keyboardShortcut("t")
            Button("Previous") { nav.shift(-1) }.keyboardShortcut(.leftArrow)
            Button("Next") { nav.shift(1) }.keyboardShortcut(.rightArrow)
            Divider()
            Button("Day") { nav.mode = .day }.keyboardShortcut("1")
            Button("Week") { nav.mode = .week }.keyboardShortcut("2")
            Button("Month") { nav.mode = .month }.keyboardShortcut("3")
            Divider()
            Button("Next Calendar Set") { manager.cycleSet() }.keyboardShortcut("]")
            Button("Previous Calendar Set") { for _ in 0..<(manager.sets.count - 1) { manager.cycleSet() } }.keyboardShortcut("[")
        }
    }
}
