import SwiftUI
import AppKit
import CalendarCore

/// Drives the status-item text. Must NOT be a `TimelineView` in the label: SwiftUI re-renders a menu-bar label to an
/// image on each update, and a self-updating view there loops forever and blocks launch. A timer-fed model is safe.
@MainActor @Observable
final class MenuBarModel {
    private(set) var title: String?
    private(set) var visible = true
    @ObservationIgnored private var task: Task<Void, Never>?

    func start(manager: EventStoreManager) {
        guard task == nil else { return }
        task = Task { [weak self] in
            var lastRevision = -1, lastRefresh = Date.distantPast, lastPrefs = AppPrefs()
            while !Task.isCancelled {
                PrefsStore.shared.reloadFromDisk()   // the main app may have changed settings
                let prefs = PrefsStore.shared.values
                if self?.visible != prefs.menuBarEnabled { self?.visible = prefs.menuBarEnabled }
                if manager.revision != lastRevision || prefs != lastPrefs || Date().timeIntervalSince(lastRefresh) >= 30 {
                    lastRevision = manager.revision; lastRefresh = Date(); lastPrefs = prefs
                    let now = Date()
                    let new = MenuBarFormat.text(manager.events(from: now, to: now.addingTimeInterval(24 * 3600)), now: now, prefs: prefs)
                    if self?.title != new { self?.title = new }
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}

struct MenuBarLabel: View {
    @Environment(MenuBarModel.self) private var model
    @Environment(EventStoreManager.self) private var manager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
            if let t = model.title { Text(t) }
        }
        .task {
            if manager.eventAccess == .notDetermined { await manager.requestAccess() }
            model.start(manager: manager)
        }
    }
}

/// Opens things in the main Tempo app through its URL scheme (launches it if it isn't running).
enum MainApp {
    static func open(_ link: DeepLink) { NSWorkspace.shared.open(link.url) }
}

struct MenuBarPopover: View {
    @Environment(EventStoreManager.self) private var manager
    @State private var selected = Date()
    private let cal = Calendar.tempo

    var body: some View {
        let today = cal.startOfDay(for: .now)
        let events = manager.events(from: today, to: cal.date(byAdding: .day, value: 2, to: today)!)
        let lead = Double(PrefsStore.shared.values.joinLeadMinutes) * 60
        let joinable = Agenda.current(events, at: .now) ?? Agenda.next(events, after: .now).flatMap { $0.start.timeIntervalSinceNow < lead ? $0 : nil }

        VStack(alignment: .leading, spacing: 10) {
            if manager.eventAccess != .full { AccessPrompt() }
            else {
                if let e = joinable, let link = e.meetingLink {
                    JoinButton(link: link, prominent: true).frame(maxWidth: .infinity)
                    Text("\(e.title) · \(e.timeRangeText)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                MiniMonthView(selected: $selected)
                Picker("Set", selection: Binding(get: { manager.activeSetID }, set: { manager.setActive($0) })) {
                    ForEach(manager.sets) { Text($0.name).tag($0.id) }
                }.pickerStyle(.segmented).labelsHidden()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        section("Today", Agenda.events(events, on: today))
                        section("Tomorrow", Agenda.events(events, on: cal.date(byAdding: .day, value: 1, to: today)!))
                    }
                }.frame(maxHeight: 220)

                QuickAddView(autofocus: false).padding(8).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            Divider()
            HStack {
                Button("Open Tempo") { MainApp.open(.today) }
                Button("Settings…") { MainApp.open(.settings) }
                Spacer()
                Button("Quit Menu Bar") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }.buttonStyle(.borderless).font(.callout)
        }
        .padding(12).frame(width: 340)
    }

    @ViewBuilder private func section(_ title: String, _ events: [EventItem]) -> some View {
        Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        if events.isEmpty { Text("Nothing scheduled").font(.caption).foregroundStyle(.tertiary) }
        ForEach(events) { e in
            EventRow(event: e).contentShape(Rectangle()).onTapGesture { MainApp.open(.event(e.eventID)) }
        }
    }
}
