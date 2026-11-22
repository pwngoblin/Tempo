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
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
                let all = manager.events(from: today, to: cal.date(byAdding: .day, value: 2, to: today)!)
                let events = all.filter { $0.start < tomorrow && ($0.isAllDay || $0.end > .now) }
                let later = all.filter { $0.start >= tomorrow }
                let focus = Agenda.current(events, at: .now) ?? Agenda.next(events, after: .now)
                List {
                    NowNextCard(events: events)
                        .listRowBackground(Color.clear)
                    if !events.isEmpty {
                        Section {
                            ForEach(events) { e in NavigationLink { WatchEventDetail(event: e) } label: { EventRow(event: e) } }
                        } header: { DaySummary(events: events) }
                    }
                    if !later.isEmpty {
                        Section("Tomorrow · \(later.count)") {
                            ForEach(later) { e in NavigationLink { WatchEventDetail(event: e) } label: { EventRow(event: e) } }
                        }
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

/// "3 left · Free until 14:00" style header for today's list.
struct DaySummary: View {
    let events: [EventItem]
    var body: some View {
        let now = Date.now
        let left = events.filter { !$0.isAllDay && $0.end > now }.count
        let status: String = {
            if let b = Agenda.busyUntil(events, at: now) { return "Busy until \(b.timeText)" }
            if let f = Agenda.freeUntil(events, at: now) { return "Free until \(f.timeText)" }
            return "Free"
        }()
        Text("Today · \(left) left · \(status)").lineLimit(2)
    }
}

/// Everything we know about one event, readable at a glance on the wrist.
struct WatchEventDetail: View {
    let event: EventItem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(event.color)).frame(width: 4, height: 18)
                    Text(event.calendarTitle).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(event.title).font(.headline)
                row("clock", event.isAllDay ? "All day" : event.timeRangeText, sub: event.isAllDay ? nil : duration)
                if let l = event.location, !l.isEmpty { row("mappin.and.ellipse", l) }
                if let m = event.meetingLink { row(m.provider.symbol, m.provider.name, sub: m.url.host) }
                if event.hasRecurrence { row("repeat", "Repeats") }
                if let n = event.attendeeCount { row("person.2", n == 1 ? "1 person" : "\(n) people") }
                if let notes = event.notes { Text(notes).font(.caption2).foregroundStyle(.secondary).lineLimit(8) }
                if !event.isAllDay, event.end > .now {
                    let isNow = event.start <= .now
                    (Text(isNow ? "Ends in " : "Starts in ") + Text(isNow ? event.end : event.start, style: .timer).monospacedDigit())
                        .font(.footnote.weight(.semibold)).foregroundStyle(Color(event.color))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Event")
    }
    private var duration: String {
        let m = Int(event.end.timeIntervalSince(event.start) / 60)
        return m >= 60 ? (m % 60 == 0 ? "\(m / 60) h" : "\(m / 60) h \(m % 60) min") : "\(m) min"
    }
    private func row(_ icon: String, _ text: String, sub: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).frame(width: 18).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(text).font(.footnote)
                if let sub { Text(sub).font(.caption2).foregroundStyle(.secondary) }
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
            HStack(spacing: 4) {
                Text(tag).font(.caption2.weight(.bold)).foregroundStyle(Color(e.color))
                if let m = e.meetingLink { Image(systemName: m.provider.symbol).font(.caption2).foregroundStyle(.secondary) }
            }
            Text(e.title).font(.headline).lineLimit(2)
            Text(e.timeRangeText).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            if let l = e.location, !l.isEmpty { Label(l, systemImage: "mappin").labelStyle(.titleAndIcon).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            (Text("\(label) ").foregroundStyle(.secondary) + Text(date, style: .timer).monospacedDigit()).font(.footnote)
            if tag == "NOW", !e.isAllDay {
                ProgressView(timerInterval: e.start...max(e.end, e.start.addingTimeInterval(1)), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(Color(e.color))
            }
            if let f = events.filter({ $0.id != e.id }).first(where: { $0.start >= e.end || ($0.start > e.start) }) {
                Text("Then \(f.start.timeText) \(f.title)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}
