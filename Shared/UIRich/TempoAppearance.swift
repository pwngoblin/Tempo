import SwiftUI
import CalendarCore

/// Applies the user's theme + accent and syncs the preferred calendar into the manager. Put once at each app root.
struct TempoAppearance: ViewModifier {
    let manager: EventStoreManager
    func body(content: Content) -> some View {
        let p = PrefsStore.shared.values
        content
            .preferredColorScheme(p.theme.scheme)
            .tint(p.accent == .system ? nil : p.accent.color)
            .onChange(of: p.preferredCalendarID, initial: true) { _, new in if manager.preferredCalendarID != new { manager.preferredCalendarID = new } }
    }
}

extension View {
    func tempoAppearance(_ manager: EventStoreManager) -> some View { modifier(TempoAppearance(manager: manager)) }
}
