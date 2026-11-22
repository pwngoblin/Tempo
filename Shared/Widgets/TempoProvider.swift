import WidgetKit
import SwiftUI
import CalendarCore

struct TempoEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]
    let set: CalendarSet
    let sets: [CalendarSet]
    let access: AccessState
    var options = WidgetOptions.default

    var current: EventItem? { Agenda.current(events, at: date) }
    var next: EventItem? { Agenda.next(events, after: date) }
    var following: EventItem? {
        guard let anchor = current ?? next else { return nil }
        return Agenda.next(events.filter { $0.id != anchor.id }, after: max(anchor.start, date))
    }

    static func sample(_ now: Date = .now) -> TempoEntry {
        func e(_ id: String, _ title: String, _ s: Double, _ d: Double, _ c: RGBA) -> EventItem {
            EventItem(eventID: id, title: title, start: now.addingTimeInterval(s * 60), end: now.addingTimeInterval((s + d) * 60), color: c)
        }
        let blue = RGBA(r: 0.2, g: 0.5, b: 1), green = RGBA(r: 0.2, g: 0.75, b: 0.4), orange = RGBA(r: 1, g: 0.6, b: 0.1)
        return TempoEntry(date: now, events: [e("1", "Team Sync", -10, 45, blue), e("2", "Gym", 90, 60, green), e("3", "Design Review", 200, 45, orange),
                                              e("4", "Dinner", 1500, 90, green), e("5", "Planning", 1700, 60, blue)],
                          set: .all, sets: [.all], access: .full)
    }
}

/// One provider for every Tempo widget. Reads the user's `TempoWidgetIntent` options; watchOS keeps the
/// window and entry count small to respect refresh budgets.
struct TempoProvider: AppIntentTimelineProvider {
    typealias Intent = TempoWidgetIntent
    /// The switcher widget always shows the globally active set (its buttons change it).
    var followsActiveSetOnly = false

    #if os(watchOS)
    private let maxDays = 2, maxEntries = 10, minReload: TimeInterval = 30 * 60, horizon: TimeInterval = 12 * 3600
    #else
    private let maxDays = 14, maxEntries = 24, minReload: TimeInterval = 15 * 60, horizon: TimeInterval = 24 * 3600
    #endif

    func placeholder(in context: Context) -> TempoEntry { .sample() }

    #if os(watchOS)
    /// Complications are edited on the watch face; these are the ready-made choices in the gallery.
    func recommendations() -> [AppIntentRecommendation<TempoWidgetIntent>] {
        var out = [AppIntentRecommendation(intent: TempoWidgetIntent(), description: "Active Calendar Set")]
        for s in CalendarSetStore().customSets.prefix(4) {
            var i = TempoWidgetIntent(); i.set = CalendarSetEntity(s)
            out.append(AppIntentRecommendation(intent: i, description: "\(s.name)"))
        }
        return out
    }
    #endif

    func snapshot(for configuration: TempoWidgetIntent, in context: Context) async -> TempoEntry {
        PrefsSnapshot.reload()
        var e = context.isPreview ? TempoEntry.sample() : load(configuration, now: .now)
        e.options = WidgetOptions(configuration)
        return e
    }

    func timeline(for configuration: TempoWidgetIntent, in context: Context) async -> Timeline<TempoEntry> {
        PrefsSnapshot.reload()
        let now = Date()
        let base = load(configuration, now: now)
        let plan = TimelinePlanner.plan(events: base.events, now: now, maxEntries: maxEntries, horizon: horizon, minReload: minReload)
        let entries = plan.entries.map { TempoEntry(date: $0, events: base.events, set: base.set, sets: base.sets, access: base.access, options: base.options) }
        return Timeline(entries: entries, policy: .after(plan.reloadAfter))
    }

    func load(_ configuration: TempoWidgetIntent, now: Date) -> TempoEntry {
        let store = CalendarSetStore()
        let sets = store.sets
        let set = (followsActiveSetOnly ? nil : configuration.set.flatMap { c in sets.first { $0.id == c.id } }) ?? store.active
        let options = WidgetOptions(configuration)
        var e = Self.read(set: set, sets: sets, now: now, daysAhead: min(options.daysAhead, maxDays))
        e.options = options
        return TempoEntry(date: e.date, events: options.filter(e.events), set: e.set, sets: e.sets, access: e.access, options: options)
    }

    static func read(set: CalendarSet, sets: [CalendarSet], now: Date, daysAhead: Int) -> TempoEntry {
        let cal = Calendar.tempo
        let access = EventReader.eventAccess
        #if os(watchOS)
        let from = cal.startOfDay(for: now)
        let to = cal.date(byAdding: .day, value: daysAhead, to: from)!
        #else
        let from = cal.dateInterval(of: .month, for: now)?.start ?? cal.startOfDay(for: now)
        let monthEnd = cal.dateInterval(of: .month, for: now)?.end ?? now
        let to = max(monthEnd, cal.date(byAdding: .day, value: daysAhead, to: cal.startOfDay(for: now))!)
        #endif
        let events = EventReader().events(from: from, to: to, in: set)
        return TempoEntry(date: now, events: events, set: set, sets: sets, access: access)
    }
}
