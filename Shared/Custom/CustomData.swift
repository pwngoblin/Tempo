import Foundation
import CalendarCore
import Widgetry

/// Where the user's custom widget specs live (App Group, so widgets can read them). Falls back to Application Support
/// when the App Group isn't available (unsigned builds), so the editor still works.
enum TempoSpecStore {
    static let shared: SpecStore = {
        let store: SpecStore
        if let s = SpecStore(appGroup: AppGroup.identifier) { store = s }
        else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            store = SpecStore(directory: dir.appendingPathComponent("Tempo", isDirectory: true))
        }
        store.onChange = { WidgetryReload.reload() }
        return store
    }()
}

/// Exposes the calendar to Widgetry specs. Read-only: it only reads `EventItem`s that were already loaded.
///
/// Fields (see `availablePaths`): focus event (current, else next) as `title start end subtitle location calendar
/// meeting when minutes`, state as `isActive progress countdown hasEvent hasLocation hasMeeting isFree`, day summary as
/// `status leftToday todayCount freeUntil busyUntil heading`, and lists `items` (upcoming, any day) and `today`
/// (rest of today) whose rows have `title start end when day location calendar`.
struct TempoCustomData: WidgetDataSource {
    var events: [EventItem]
    var access: AccessState = .full
    var calendar: Calendar = .tempo

    var availablePaths: [FieldInfo] {
        [
            .init(path: "title", title: "Event title", kind: .text),
            .init(path: "subtitle", title: "Place or calendar", kind: .text),
            .init(path: "location", title: "Location", kind: .text),
            .init(path: "calendar", title: "Calendar name", kind: .text),
            .init(path: "meeting", title: "Meeting app", kind: .text),
            .init(path: "when", title: "Time range", kind: .text),
            .init(path: "status", title: "Free / busy status", kind: .text),
            .init(path: "heading", title: "Day heading", kind: .text),
            .init(path: "start", title: "Event start", kind: .date),
            .init(path: "end", title: "Event end", kind: .date),
            .init(path: "countdown", title: "Counts down to (end if now, else start)", kind: .date),
            .init(path: "freeUntil", title: "Free until", kind: .date),
            .init(path: "busyUntil", title: "Busy until", kind: .date),
            .init(path: "progress", title: "Progress of current event", kind: .number),
            .init(path: "minutes", title: "Duration (minutes)", kind: .number),
            .init(path: "leftToday", title: "Events left today", kind: .number),
            .init(path: "todayCount", title: "Events today", kind: .number),
            .init(path: "isActive", title: "Happening now", kind: .flag),
            .init(path: "hasEvent", title: "Has an event", kind: .flag),
            .init(path: "hasLocation", title: "Has a location", kind: .flag),
            .init(path: "hasMeeting", title: "Has a meeting link", kind: .flag),
            .init(path: "isFree", title: "Free right now", kind: .flag),
            .init(path: "items", title: "Upcoming events", kind: .list),
            .init(path: "today", title: "Rest of today", kind: .list),
        ]
    }

    func context(at date: Date) -> DataContext {
        var c: DataContext = ["heading": .string("Today")]
        guard access == .full else {
            c["title"] = .string("Open Tempo to allow calendar access"); c["hasEvent"] = .bool(false)
            return c
        }
        let timed = events.filter { !$0.isAllDay }
        let current = Agenda.current(timed, at: date)
        let next = Agenda.next(timed, after: date)
        let focus = current ?? next

        c["hasEvent"] = .bool(focus != nil)
        c["isActive"] = .bool(current != nil)
        c["isFree"] = .bool(current == nil)
        if let e = focus {
            c["title"] = .string(e.title)
            c["start"] = .date(e.start); c["end"] = .date(e.end)
            c["countdown"] = .date(current != nil ? e.end : e.start)
            c["when"] = .string(e.timeRangeText)
            c["calendar"] = .string(e.calendarTitle)
            c["subtitle"] = .string(e.location ?? e.calendarTitle)
            c["location"] = .string(e.location ?? ""); c["hasLocation"] = .bool(e.location?.isEmpty == false)
            c["meeting"] = .string(e.meetingLink?.provider.name ?? ""); c["hasMeeting"] = .bool(e.meetingLink != nil)
            c["minutes"] = .number((e.end.timeIntervalSince(e.start) / 60).rounded())
            if current != nil {
                let span = max(e.end.timeIntervalSince(e.start), 1)
                c["progress"] = .number(min(max(date.timeIntervalSince(e.start) / span, 0), 1))
            }
        } else {
            c["title"] = .string("Nothing coming up")
        }

        let busy = Agenda.busyUntil(timed, at: date), free = Agenda.freeUntil(timed, at: date)
        if let busy { c["busyUntil"] = .date(busy); c["status"] = .string("Busy until \(busy.timeText)") }
        else if let free { c["freeUntil"] = .date(free); c["status"] = .string("Free until \(free.timeText)") }
        else { c["status"] = .string("Free") }

        let today = Agenda.events(timed, on: date, calendar: calendar)
        let left = today.filter { $0.end > date }
        c["todayCount"] = .number(Double(today.count)); c["leftToday"] = .number(Double(left.count))
        c["today"] = .list(left.prefix(12).map(row))
        c["items"] = .list(timed.filter { $0.end > date }.sorted { $0.start < $1.start }.prefix(12).map(row))
        return c
    }

    func changeDates(from start: Date, to end: Date) -> [Date] {
        events.filter { !$0.isAllDay }.flatMap { [$0.start, $0.end] }.filter { $0 > start && $0 <= end }
    }

    private func row(_ e: EventItem) -> DataContext {
        ["title": .string(e.title), "start": .date(e.start), "end": .date(e.end), "when": .string(e.timeRangeText),
         "day": .string(e.start.formatted(.dateTime.weekday(.abbreviated))), "location": .string(e.location ?? ""),
         "calendar": .string(e.calendarTitle)]
    }
}
