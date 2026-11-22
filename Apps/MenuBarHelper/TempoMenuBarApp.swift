import SwiftUI
import CalendarCore

/// Tiny background app (no Dock icon) that owns the status item. It is a separate process from the main app,
/// so the menu-bar countdown and popover stay put when the main Tempo app is closed or quit.
@main
struct TempoMenuBarApp: App {
    @State private var manager = EventStoreManager()
    @State private var model = MenuBarModel()

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(get: { model.visible }, set: { _ in })) {
            MenuBarPopover().environment(manager).tempoAppearance(manager)
        } label: {
            MenuBarLabel().environment(manager).environment(model)
        }
        .menuBarExtraStyle(.window)
    }
}
