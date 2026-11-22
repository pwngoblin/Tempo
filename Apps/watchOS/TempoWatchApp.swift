import SwiftUI
import CalendarCore

@main
struct TempoWatchApp: App {
    @State private var manager = EventStoreManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(manager)
                .task {
                    await manager.requestAccess()
                    WatchLink.shared.onSetsImported = { manager.reloadSets() }
                    WatchLink.shared.activate()
                }
                .onOpenURL { url in if case .set(let id) = DeepLink(url: url) { manager.setActive(id) } }
        }
    }
}

struct WatchContentView: View {
    @Environment(EventStoreManager.self) private var manager
    @State private var adding = false
    private let cal = Calendar.tempo

    var body: some View {
        NavigationStack {
            if manager.eventAccess != .full { AccessPrompt() }
            else {
                let today = cal.startOfDay(for: .now)
                let events = manager.events(from: today, to: cal.date(byAdding: .day, value: 1, to: today)!)
                    .filter { $0.isAllDay || $0.end > .now }
                let focus = Agenda.current(events, at: .now) ?? Agenda.next(events, after: .now)
                List {
                    NowNextCard(events: events)
                        .listRowBackground(Color.clear)
                    if !events.isEmpty {
                        Section("Today") { ForEach(events) { EventRow(event: $0) } }
                    }
                    Section {
                        SetPicker()
                        if let ack = WatchLink.shared.lastAck { Label(ack, systemImage: "iphone").font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                .navigationTitle(manager.activeSet.name)
                .containerBackground((focus.map { Color($0.color) } ?? .gray).gradient.opacity(0.45), for: .navigation)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { adding = true } label: { Label("Add Event", systemImage: "plus") }
                    }
                }
                .sheet(isPresented: $adding) {
                    ScrollView { QuickAddView { adding = false }.padding() }.environment(manager)
                }
            }
        }
    }
}

/// Current event (ends in …) or next event (starts in …) with a live system countdown.
struct NowNextCard: View {
    let events: [EventItem]
    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let now = ctx.date
            VStack(alignment: .leading, spacing: 2) {
                if let cur = Agenda.current(events, at: now) { block("NOW", cur, label: "ends in", date: cur.end) }
                else if let next = Agenda.next(events, after: now) { block("NEXT", next, label: "starts in", date: next.start) }
                else { Label("Free", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(.green) }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func block(_ tag: String, _ e: EventItem, label: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tag).font(.caption2.weight(.bold)).foregroundStyle(Color(e.color))
            Text(e.title).font(.headline).lineLimit(2)
            (Text("\(label) ").foregroundStyle(.secondary) + Text(date, style: .timer).monospacedDigit()).font(.footnote)
        }
    }
}
