import SwiftUI
import CalendarCore

@main
struct TempoIOSApp: App {
    @State private var manager = EventStoreManager()
    @State private var nav = Navigator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(manager).environment(nav)
                .tempoAppearance(manager)
                .tempoInterfaceScale()
                .task {
                    await manager.requestAccess()
                    WatchLink.shared.onAddRequest = { text, at in
                        guard let p = EventParser().parse(text, now: at) else { return "Couldn't parse “\(text)”" }
                        do { return "Added \(try manager.create(p).title)" } catch { return error.localizedDescription }
                    }
                    WatchLink.shared.activate()
                }
                .onChange(of: scenePhase) { _, phase in if phase == .active { manager.refreshSources() } }
                .onChange(of: manager.sets) { _, _ in WatchLink.shared.pushSets() }
                .onOpenURL { nav.handle($0, manager: manager) }
        }
    }
}

enum ViewMode: String, CaseIterable, Identifiable {
    case agenda = "Agenda", week = "Week", month = "Month"
    var id: String { rawValue }
}

@MainActor @Observable
final class Navigator {
    var date = Date()
    var mode: ViewMode = ViewMode(rawValue: PrefsStore.shared.values.defaultViewPhone.capitalized) ?? .agenda
    var showQuickAdd = false
    var quickAddText: String?
    var editor: EditorTarget?
    var detail: EventItem?
    var showSettings = false
    var settingsPage: SettingsView.Page?

    func handle(_ url: URL, manager: EventStoreManager) {
        let cal = Calendar.tempo
        switch DeepLink(url: url) {
        case .today: date = .now; mode = .agenda
        case .day(let iso): if let d = DeepLink.date(from: iso) { date = d; mode = .week }
        case .set(let id): manager.setActive(id)
        case .settings: showSettings = true
        case .add(let t): quickAddText = t; showQuickAdd = true
        case .event(let id):
            let start = cal.startOfDay(for: date)
            if let e = manager.events(from: cal.date(byAdding: .month, value: -1, to: start)!, to: cal.date(byAdding: .month, value: 2, to: start)!)
                .first(where: { $0.eventID == id }) { date = e.start; detail = e }
        case nil: break
        }
    }
}
