import Foundation
import EventKit
import Observation
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum EventStoreError: LocalizedError {
    case noAccess, noWritableCalendar, notFound, readOnlyPlatform
    public var errorDescription: String? {
        switch self {
        case .readOnlyPlatform: "EventKit is read-only on Apple Watch. Edits are made on the paired iPhone."
        case .noAccess: "Calendar access is not granted. Enable it in System Settings › Privacy & Security."
        case .noWritableCalendar: "No writable calendar is available."
        case .notFound: "The event no longer exists."
        }
    }
}

public enum RecurrenceSpan: Sendable {
    case thisEvent, futureEvents
    var ek: EKSpan { self == .thisEvent ? .thisEvent : .futureEvents }
}

/// Observable façade over `EKEventStore` for the app UIs: access, CRUD with recurrence spans,
/// Calendar Sets, reminders, and automatic refresh (UI + widgets) on `.EKEventStoreChanged`.
@MainActor @Observable
public final class EventStoreManager {
    public let store: EKEventStore
    public private(set) var eventAccess: AccessState = .notDetermined
    public private(set) var reminderAccess: AccessState = .notDetermined
    public private(set) var calendars: [CalendarInfo] = []
    public private(set) var reminderLists: [CalendarInfo] = []
    public private(set) var sets: [CalendarSet] = [.all]
    /// Bumped on every store change; views read it (via `events(...)`) to re-render.
    public private(set) var revision = 0
    public private(set) var activeSetID: UUID = CalendarSet.allID
    public var lastError: String?
    /// Calendars the user hid (filters display only). Persisted in the App Group so widgets agree.
    public private(set) var hiddenCalendarIDs: Set<String> = []
    /// Preferred calendar for new events (from Settings); used when the phrase has no `#calendar`.
    public var preferredCalendarID: String?

    @ObservationIgnored private let setStore: CalendarSetStore
    @ObservationIgnored private let visibility = CalendarVisibility()
    @ObservationIgnored private var observers: [Task<Void, Never>] = []
    @ObservationIgnored private var reader: EventReader { EventReader(store: store) }

    public init(store: EKEventStore = EKEventStore(), setStore: CalendarSetStore = CalendarSetStore(cloud: .default)) {
        self.store = store; self.setStore = setStore
        refreshAccess(); reloadCalendars(); reloadSets(); hiddenCalendarIDs = visibility.hidden
        startObserving()
    }

    deinit { observers.forEach { $0.cancel() } }

    // MARK: Access
    public func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        #if !os(watchOS)
        _ = try? await store.requestFullAccessToReminders()
        #endif
        refreshAccess(); reloadCalendars(); bump()
    }

    private func refreshAccess() {
        eventAccess = accessState(EKEventStore.authorizationStatus(for: .event))
        #if !os(watchOS)
        reminderAccess = accessState(EKEventStore.authorizationStatus(for: .reminder))
        #endif
    }

    // MARK: Observing
    private func startObserving() {
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                guard let self else { return }
                self.refreshAccess(); self.reloadCalendars(); self.bump()
            }
        })
        observers.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification) {
                guard let self else { return }
                if self.setStore.pullFromCloud() { self.reloadSets(); self.reloadWidgets() }
            }
        })
    }

    private func bump() { revision &+= 1; reloadWidgets() }

    public func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func reloadCalendars() {
        guard eventAccess == .full else { calendars = []; reminderLists = []; return }
        calendars = reader.calendars()
        #if !os(watchOS)
        reminderLists = store.calendars(for: .reminder).map(CalendarInfo.init)
        #endif
    }

    /// Ask EventKit to pick up calendars subscribed outside the app (call when the app becomes active).
    public func refreshSources() {
        #if !os(watchOS)
        store.refreshSourcesIfNecessary()
        #endif
        reloadCalendars(); bump()
    }

    public func setCalendar(_ id: String, visible: Bool) {
        visibility.setHidden(id, !visible); hiddenCalendarIDs = visibility.hidden; bump()
    }

    public var subscribedCalendars: [CalendarInfo] { calendars.filter(\.isSubscribed) }

    // MARK: Calendar Sets
    public func reloadSets() { sets = setStore.sets; activeSetID = setStore.activeID }
    public var activeSet: CalendarSet { sets.first { $0.id == activeSetID } ?? .all }

    public func setActive(_ id: UUID) { setStore.activeID = id; activeSetID = setStore.activeID; bump() }
    public func cycleSet() { setStore.cycle(); activeSetID = setStore.activeID; bump() }
    public func saveSets(_ custom: [CalendarSet]) { setStore.save(custom); reloadSets(); bump() }
    public var customSets: [CalendarSet] { sets.filter { $0.id != CalendarSet.allID } }

    // MARK: Reading
    public func events(from start: Date, to end: Date, in set: CalendarSet? = nil) -> [EventItem] {
        _ = revision; _ = hiddenCalendarIDs   // register observation dependencies
        return reader.events(from: start, to: end, in: set ?? activeSet)
    }

    public func ekEvent(for item: EventItem) -> EKEvent? {
        let predicate = store.predicateForEvents(withStart: item.start.addingTimeInterval(-60), end: item.end.addingTimeInterval(60), calendars: nil)
        return store.events(matching: predicate).first { $0.eventIdentifier == item.eventID && $0.startDate == item.start }
            ?? store.event(withIdentifier: item.eventID)
    }

    // MARK: Writing
    public var writableCalendars: [CalendarInfo] { calendars.filter(\.allowsModify) }

    public func resolveCalendar(hint: String?) -> EKCalendar? {
        let writable = store.calendars(for: .event).filter(\.allowsContentModifications)
        if let h = hint?.lowercased(), !h.isEmpty {
            if let c = writable.first(where: { $0.title.lowercased() == h })
                ?? writable.first(where: { $0.title.lowercased().hasPrefix(h) })
                ?? writable.first(where: { $0.title.lowercased().contains(h) }) { return c }
        }
        if let id = preferredCalendarID, let c = writable.first(where: { $0.calendarIdentifier == id }) { return c }
        if !activeSet.includesAll, let c = writable.first(where: { activeSet.contains(CalendarInfo($0)) }) { return c }
        return store.defaultCalendarForNewEvents.flatMap { $0.allowsContentModifications ? $0 : nil } ?? writable.first
    }

    #if os(watchOS)
    @discardableResult public func create(_ parsed: ParsedEvent) throws -> EventItem { throw EventStoreError.readOnlyPlatform }
    @discardableResult
    public func create(title: String, start: Date, end: Date, isAllDay: Bool = false, location: String? = nil,
                       notes: String? = nil, calendar: EKCalendar) throws -> EventItem { throw EventStoreError.readOnlyPlatform }
    public func update(_ item: EventItem, title: String? = nil, start: Date? = nil, end: Date? = nil, isAllDay: Bool? = nil,
                       location: String?? = nil, calendarID: String? = nil, span: RecurrenceSpan = .thisEvent) throws { throw EventStoreError.readOnlyPlatform }
    public func delete(_ item: EventItem, span: RecurrenceSpan = .thisEvent) throws { throw EventStoreError.readOnlyPlatform }
    #else
    @discardableResult
    public func create(_ parsed: ParsedEvent) throws -> EventItem {
        guard eventAccess == .full else { throw EventStoreError.noAccess }
        guard let cal = resolveCalendar(hint: parsed.calendarHint) else { throw EventStoreError.noWritableCalendar }
        return try create(title: parsed.title, start: parsed.start, end: parsed.end, isAllDay: parsed.isAllDay, location: parsed.location, calendar: cal)
    }

    @discardableResult
    public func create(title: String, start: Date, end: Date, isAllDay: Bool = false, location: String? = nil,
                       notes: String? = nil, calendar: EKCalendar) throws -> EventItem {
        let e = EKEvent(eventStore: store)
        e.title = title; e.startDate = start; e.endDate = end; e.isAllDay = isAllDay
        e.location = location; e.notes = notes; e.calendar = calendar
        try store.save(e, span: .thisEvent, commit: true)
        bump()
        return EventItem(e)
    }

    public func update(_ item: EventItem, title: String? = nil, start: Date? = nil, end: Date? = nil, isAllDay: Bool? = nil,
                       location: String?? = nil, calendarID: String? = nil, span: RecurrenceSpan = .thisEvent) throws {
        guard let e = ekEvent(for: item) else { throw EventStoreError.notFound }
        if let title { e.title = title }
        if let start { e.startDate = start }
        if let end { e.endDate = end }
        if let isAllDay { e.isAllDay = isAllDay }
        if let location { e.location = location }
        if let calendarID, let c = store.calendar(withIdentifier: calendarID) { e.calendar = c }
        try store.save(e, span: span.ek, commit: true)
        bump()
    }

    public func delete(_ item: EventItem, span: RecurrenceSpan = .thisEvent) throws {
        guard let e = ekEvent(for: item) else { throw EventStoreError.notFound }
        try store.remove(e, span: span.ek, commit: true)
        bump()
    }
    #endif

    #if !os(watchOS)
    /// Unsubscribe / delete a calendar (only calendars the account allows to delete).
    public func removeCalendar(id: String) throws {
        guard let c = store.calendar(withIdentifier: id) else { throw EventStoreError.notFound }
        try store.removeCalendar(c, commit: true)
        reloadCalendars(); bump()
    }
    #endif

    // MARK: Reminders (not available on watchOS)
    #if !os(watchOS)
    public func reminders(includeCompleted: Bool = false) async -> [ReminderItem] {
        guard reminderAccess == .full else { return [] }
        let lists = store.calendars(for: .reminder)
        guard !lists.isEmpty else { return [] }
        let predicate = includeCompleted
            ? store.predicateForReminders(in: lists)
            : store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: lists)
        let cal = Calendar.current
        return await withCheckedContinuation { cont in
            store.fetchReminders(matching: predicate) { found in
                let items = (found ?? []).map { r in
                    ReminderItem(id: r.calendarItemIdentifier, title: r.title ?? "Untitled",
                                 due: r.dueDateComponents.flatMap { cal.date(from: $0) }, isCompleted: r.isCompleted,
                                 priority: r.priority, listTitle: r.calendar?.title ?? "", color: RGBA(cgColor: r.calendar?.cgColor))
                }
                cont.resume(returning: items.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) })
            }
        }
    }

    public func setReminder(_ id: String, completed: Bool) throws {
        guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { throw EventStoreError.notFound }
        r.isCompleted = completed
        try store.save(r, commit: true)
        bump()
    }

    @discardableResult
    public func createReminder(title: String, due: Date?) throws -> String {
        guard let list = store.defaultCalendarForNewReminders() else { throw EventStoreError.noWritableCalendar }
        let r = EKReminder(eventStore: store)
        r.title = title; r.calendar = list
        if let due {
            r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            r.addAlarm(EKAlarm(absoluteDate: due))
        }
        try store.save(r, commit: true)
        bump()
        return r.calendarItemIdentifier
    }
    #endif
}
