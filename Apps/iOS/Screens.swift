import SwiftUI
import CalendarCore

/// Next 14 days: plain list, one header per day, time-column rows. Reminders on top.
struct AgendaView: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    @State private var reminders: [ReminderItem] = []
    private let cal = Calendar.tempo

    var body: some View {
        let p = PrefsStore.shared.values
        let start = cal.startOfDay(for: nav.date)
        let events = manager.events(from: start, to: cal.date(byAdding: .day, value: p.agendaDays, to: start)!)
        let byDay = Agenda.byDay(events, calendar: cal)
        let days = (0..<p.agendaDays).compactMap { cal.date(byAdding: .day, value: $0, to: start) }.filter { byDay[$0]?.isEmpty == false }

        List {
            if p.showReminders, !reminders.isEmpty {
                Section { ForEach(reminders.prefix(6)) { ReminderRow(reminder: $0) } } header: { SectionTitle("Reminders") }
            }
            ForEach(days, id: \.self) { day in
                Section { ForEach(Agenda.events(byDay[day] ?? [], on: day, calendar: cal)) { EventListRow(event: $0) } } header: { DayHeader(day: day) }
            }
        }
        .listStyle(.plain)
        .overlay { if days.isEmpty { ContentUnavailableView("Nothing scheduled", systemImage: "calendar", description: Text("Tap + to add an event.")) } }
        .task(id: manager.revision) { reminders = await manager.reminders() }
        .refreshable { reminders = await manager.reminders() }
    }
}

/// Tappable event row with context menu and swipe-to-delete (non-recurring).
struct EventListRow: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    let event: EventItem
    var body: some View {
        EventRow(event: event)
            .contentShape(Rectangle())
            .onTapGesture { nav.detail = event }
            .contextMenu { EventMenu(event: event) }
            .swipeActions { if event.canModify && !event.hasRecurrence { Button(role: .destructive) { try? manager.delete(event) } label: { Label("Delete", systemImage: "trash") } } }
            .accessibilityAddTraits(.isButton)
    }
}

struct EventMenu: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    let event: EventItem
    var body: some View {
        if let link = event.meetingLink { Link(destination: link.url) { Label("Join \(link.provider.name)", systemImage: link.provider.symbol) } }
        if event.canModify {
            Button { nav.editor = .edit(event) } label: { Label("Edit", systemImage: "pencil") }
            if !event.hasRecurrence { Button(role: .destructive) { try? manager.delete(event) } label: { Label("Delete", systemImage: "trash") } }
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View { Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).textCase(nil) }
}

/// "TODAY  Sunday 22 Nov" – today in red, like Apple Calendar's list.
struct DayHeader: View {
    let day: Date
    var body: some View {
        let cal = Calendar.tempo
        let today = cal.isDateInToday(day)
        HStack(spacing: 6) {
            if today { Text("TODAY").font(.caption.weight(.bold)) }
            else if cal.isDateInTomorrow(day) { Text("TOMORROW").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
            Text(day, format: .dateTime.weekday(.wide).day().month(.abbreviated)).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(today ? Color.red : .primary)
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }
}

struct ReminderRow: View {
    @Environment(EventStoreManager.self) private var manager
    let reminder: ReminderItem
    @State private var ticks = 0
    var body: some View {
        HStack(spacing: 12) {
            Button { try? manager.setReminder(reminder.id, completed: !reminder.isCompleted); ticks += 1 } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle").foregroundStyle(Color(reminder.color)).imageScale(.large)
                    .frame(minWidth: 44, minHeight: 44)
            }.buttonStyle(.plain).accessibilityLabel(reminder.isCompleted ? "Mark incomplete" : "Complete")
            VStack(alignment: .leading) {
                Text(reminder.title).strikethrough(reminder.isCompleted)
                if let due = reminder.due { Text(due, format: .dateTime.month().day().hour().minute()).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .tempoHaptic(.success, trigger: ticks)
    }
}

/// Week strip on top, the selected day as an hour timeline below.
struct WeekStripView: View {
    @Environment(Navigator.self) private var nav
    @ScaledMetric(relativeTo: .title3) private var dayDiameter: CGFloat = 38
    private let cal = Calendar.tempo

    var body: some View {
        let week = cal.dateInterval(of: .weekOfYear, for: nav.date)?.start ?? nav.date
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: week) }

        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { d in
                    let sel = cal.isDate(d, inSameDayAs: nav.date), today = cal.isDateInToday(d)
                    Button { withAnimation(.snappy) { nav.date = d } } label: {
                        VStack(spacing: 4) {
                            Text(d, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
                            Text("\(cal.component(.day, from: d))").font(.title3.monospacedDigit().weight(.semibold))
                                .foregroundStyle(sel ? Color.white : today ? Color.red : .primary)
                                .frame(width: dayDiameter, height: dayDiameter)
                                .background(sel ? (today ? Color.red : Color.primary) : .clear, in: Circle())
                        }.frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(d.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(sel ? .isSelected : [])
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .gesture(DragGesture(minimumDistance: 24).onEnded { v in
                withAnimation(.snappy) { nav.date = cal.date(byAdding: .weekOfYear, value: v.translation.width < 0 ? 1 : -1, to: nav.date) ?? nav.date }
            })
            .tempoHaptic(.selection, trigger: nav.date)
            Text(nav.date, format: .dateTime.weekday(.wide).day().month(.wide).year()).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.bottom, 6)
            Divider()
            DayTimeline(day: nav.date)
        }
    }
}

struct MonthScreen: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    private let cal = Calendar.tempo

    var body: some View {
        @Bindable var nav = nav
        let start = cal.startOfDay(for: nav.date)
        let events = Agenda.events(manager.events(from: start, to: cal.date(byAdding: .day, value: 1, to: start)!), on: nav.date)
        VStack(spacing: 8) {
            MiniMonthView(selected: $nav.date, large: true).padding(.horizontal)
                .tempoHaptic(.selection, trigger: nav.date)
            Divider()
            List {
                Section { ForEach(events) { EventListRow(event: $0) } } header: { DayHeader(day: nav.date) }
            }
            .listStyle(.plain)
            .overlay { if events.isEmpty { Text("Nothing scheduled").foregroundStyle(.secondary) } }
        }
    }
}
