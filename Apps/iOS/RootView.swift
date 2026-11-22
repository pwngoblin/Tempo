import SwiftUI
import CalendarCore

struct RootView: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    @State private var haptic = 0

    var body: some View {
        @Bindable var nav = nav
        NavigationStack {
            Group {
                if manager.eventAccess != .full { AccessPrompt() }
                else {
                    VStack(spacing: 0) {
                        Picker("View", selection: $nav.mode) { ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented).padding(.horizontal).padding(.bottom, 6)
                        switch nav.mode {
                        case .agenda: AgendaView()
                        case .week: WeekStripView()
                        case .month: MonthScreen()
                        }
                    }
                }
            }
            .id(PrefsStore.shared.values.layoutKey)
            .navigationTitle(nav.mode == .month ? "" : nav.date.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { SetPicker() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { nav.date = .now; haptic += 1 } label: { Label("Today", systemImage: "calendar") }
                        Button { nav.settingsPage = nil; nav.showSettings = true } label: { Label("Settings…", systemImage: "gearshape") }
                        Button { nav.settingsPage = .sets; nav.showSettings = true } label: { Label("Calendar Sets…", systemImage: "square.stack") }
                        Button { nav.settingsPage = .subscriptions; nav.showSettings = true } label: { Label("Subscribe to Calendar…", systemImage: "dot.radiowaves.up.forward") }
                    } label: { Image(systemName: "ellipsis.circle") }
                        .accessibilityLabel("More")
                    Button { nav.showQuickAdd = true; haptic += 1 } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Quick add")
                }
            }
            .animation(.snappy, value: nav.mode)
        }
        .tempoHaptic(.impact(flexibility: .soft), trigger: haptic)
        .sheet(isPresented: $nav.showQuickAdd) {
            AddEventView { nav.showQuickAdd = false }
                .presentationDetents([.large]).environment(manager)
        }
        .sheet(item: $nav.editor) { EventEditorView(target: $0).environment(manager) }
        .sheet(item: $nav.detail) { e in EventDetailView(event: e).environment(manager).presentationDetents([.medium, .large]) }
        .sheet(isPresented: $nav.showSettings) { SettingsView(start: nav.settingsPage).environment(manager) }
    }
}
