import Foundation

/// Pure functions over `[EventItem]` shared by the apps, widgets and complications.
public enum Agenda {
    /// Timed event in progress at `date` (earliest start wins).
    public static func current(_ events: [EventItem], at date: Date) -> EventItem? {
        events.filter { !$0.isAllDay && $0.start <= date && $0.end > date }.min { $0.start < $1.start }
    }

    /// First timed event starting after `date`.
    public static func next(_ events: [EventItem], after date: Date) -> EventItem? {
        events.filter { !$0.isAllDay && $0.start > date }.min { $0.start < $1.start }
    }

    public static func upcoming(_ events: [EventItem], from date: Date, limit: Int) -> [EventItem] {
        Array(events.filter { $0.end > date }.sorted { $0.start < $1.start }.prefix(limit))
    }

    /// If free at `date`, when the next event begins ("Free until 16:30"); nil if busy or nothing ahead.
    public static func freeUntil(_ events: [EventItem], at date: Date) -> Date? {
        guard current(events, at: date) == nil else { return nil }
        return next(events, after: date)?.start
    }

    /// If busy at `date`, when the back-to-back run of events ends.
    public static func busyUntil(_ events: [EventItem], at date: Date) -> Date? {
        guard let first = current(events, at: date) else { return nil }
        var end = first.end
        for e in events.filter({ !$0.isAllDay }).sorted(by: { $0.start < $1.start }) where e.start <= end && e.end > end { end = e.end }
        return end
    }

    public static func events(_ events: [EventItem], on day: Date, calendar: Calendar = .current) -> [EventItem] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return events.filter { $0.start < end && max($0.end, $0.start.addingTimeInterval(1)) > start }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }

    /// Events bucketed per start-of-day; multi-day events appear on each day they cover.
    public static func byDay(_ events: [EventItem], calendar: Calendar = .current) -> [Date: [EventItem]] {
        var out: [Date: [EventItem]] = [:]
        for e in events {
            var day = calendar.startOfDay(for: e.start)
            let last = calendar.startOfDay(for: e.end > e.start ? e.end.addingTimeInterval(-1) : e.start)
            while day <= last {
                out[day, default: []].append(e)
                guard let n = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = n
            }
        }
        return out
    }

    /// Merged busy intervals of timed events, clipped to `day`.
    public static func busyBlocks(_ events: [EventItem], on day: Date, calendar: Calendar = .current) -> [DateInterval] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let clipped = events.filter { !$0.isAllDay }
            .compactMap { e -> DateInterval? in
                let s = max(e.start, start), t = min(e.end, end)
                return t > s ? DateInterval(start: s, end: t) : nil
            }.sorted { $0.start < $1.start }
        var merged: [DateInterval] = []
        for b in clipped {
            if let last = merged.last, b.start <= last.end { merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, b.end)) }
            else { merged.append(b) }
        }
        return merged
    }

    public struct Placed: Identifiable, Hashable, Sendable {
        public var event: EventItem
        public var column: Int
        public var columns: Int
        public var id: String { event.id }
    }

    /// Greedy column packing so overlapping events sit side by side in a time grid.
    public static func layout(_ events: [EventItem]) -> [Placed] {
        let sorted = events.filter { !$0.isAllDay }.sorted { ($0.start, $1.end) < ($1.start, $0.end) }
        var result: [Placed] = []
        var cluster: [(EventItem, Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast
        func flush() {
            let n = max(columnEnds.count, 1)
            result += cluster.map { Placed(event: $0.0, column: $0.1, columns: n) }
            cluster = []; columnEnds = []
        }
        for e in sorted {
            if e.start >= clusterEnd { flush() }
            let col = columnEnds.firstIndex { $0 <= e.start } ?? columnEnds.count
            if col == columnEnds.count { columnEnds.append(e.end) } else { columnEnds[col] = e.end }
            cluster.append((e, col)); clusterEnd = max(clusterEnd, e.end)
        }
        flush()
        return result
    }
}

/// Bounded timeline schedule so widgets/complications respect refresh budgets (esp. watchOS).
/// Entries land only on moments the display really changes (event start/end, midnight); live
/// countdowns use `Text(date, style: .timer)` so no per-minute entries are needed.
public enum TimelinePlanner {
    public struct Plan: Equatable, Sendable {
        public var entries: [Date]
        public var reloadAfter: Date
    }

    public static func plan(events: [EventItem], now: Date, maxEntries: Int, horizon: TimeInterval,
                            minReload: TimeInterval, calendar: Calendar = .current) -> Plan {
        let limit = now.addingTimeInterval(horizon)
        var points = Set<Date>()
        for e in events where !e.isAllDay {
            for d in [e.start, e.end] where d > now && d <= limit { points.insert(d) }
        }
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)), midnight <= limit { points.insert(midnight) }
        let entries = [now] + points.sorted().prefix(max(maxEntries - 1, 0))
        let last = entries.last ?? now
        // Reload once the last scheduled entry is reached, but never more often than `minReload`.
        let reload = max(last, now.addingTimeInterval(minReload))
        return Plan(entries: entries, reloadAfter: min(reload, limit.addingTimeInterval(minReload)))
    }
}
