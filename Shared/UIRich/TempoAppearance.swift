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

/// Applies the user's interface size. iOS: Dynamic Type + control size. macOS: layout zoom of the window content.
struct InterfaceScale: ViewModifier {
    func body(content: Content) -> some View {
        let size = PrefsStore.shared.values.interfaceSize
        #if os(macOS)
        GeometryReader { g in
            content
                .frame(width: g.size.width / size.zoom, height: g.size.height / size.zoom)
                .scaleEffect(size.zoom, anchor: .topLeading)
                .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
        #else
        content
            .transformEnvironment(\.dynamicTypeSize) { if let t = size.dynamicType { $0 = t } }
            .controlSize(size == .compact || size == .small ? .small : size == .large ? .large : .regular)
        #endif
    }
}

extension View {
    /// Main window / root content only (not Settings): sizes the whole interface per preference.
    func tempoInterfaceScale() -> some View { modifier(InterfaceScale()) }

    func tempoAppearance(_ manager: EventStoreManager) -> some View { modifier(TempoAppearance(manager: manager)) }
}
