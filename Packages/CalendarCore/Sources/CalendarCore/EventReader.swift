import Foundation
import EventKit

public extension EventItem {
    init(_ e: EKEvent) {
        let eventID = e.eventIdentifier ?? UUID().uuidString
        self.init(
            eventID: eventID,
            title: (e.title?.isEmpty == false ? e.title : nil) ?? "Untitled",
            start: e.startDate, end: e.endDate ?? e.startDate, isAllDay: e.isAllDay,
            location: e.location?.isEmpty == false ? e.location : nil,
            calendarID: e.calendar?.calendarIdentifier ?? "", calendarTitle: e.calendar?.title ?? "",
            color: RGBA(cgColor: e.calendar?.cgColor),
            meetingLink: MeetingLinkExtractor.extract(url: e.url, location: e.location, notes: e.notes),
            hasRecurrence: e.hasRecurrenceRules, canModify: e.calendar?.allowsContentModifications ?? false,
            notes: e.notes.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)) },
            attendeeCount: e.attendees.flatMap { $0.isEmpty ? nil : $0.count })
    }
}

public extension CalendarInfo {
    init(_ c: EKCalendar) {
        self.init(id: c.calendarIdentifier, title: c.title, source: c.source?.title ?? "",
                  color: RGBA(cgColor: c.cgColor), allowsModify: c.allowsContentModifications,
                  isReminderList: c.allowedEntityTypes.contains(.reminder) && !c.allowedEntityTypes.contains(.event),
                  isSubscribed: c.type == .subscription)
    }
}

public func accessState(_ s: EKAuthorizationStatus) -> AccessState {
    switch s {
    case .notDetermined: .notDetermined
    case .restricted: .restricted
    case .denied: .denied
    case .writeOnly: .writeOnly
    default: .full
    }
}

/// Lightweight, non-actor EventKit reader. Used by widget timeline providers (no UI state) and
/// by `EventStoreManager`.
public struct EventReader: @unchecked Sendable {
    public let store: EKEventStore
    public init(store: EKEventStore = EKEventStore()) { self.store = store }

    public static var eventAccess: AccessState { accessState(EKEventStore.authorizationStatus(for: .event)) }

    public func calendars() -> [CalendarInfo] {
        store.calendars(for: .event).map(CalendarInfo.init).sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    /// Events in `[start, end)` for calendars in `set`; declined and cancelled events are skipped.
    public func events(from start: Date, to end: Date, in set: CalendarSet = .all, respectHidden: Bool = true) -> [EventItem] {
        guard Self.eventAccess == .full else { return [] }
        let hidden = respectHidden ? CalendarVisibility().hidden : []
        let all = store.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
        let selected = set.includesAll ? all : all.filter { set.contains(CalendarInfo($0)) }
        guard !selected.isEmpty else { return [] }   // never pass [] — EventKit treats nil as "all"
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: selected)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled && $0.attendees?.first(where: \.isCurrentUser)?.participantStatus != .declined }
            .map(EventItem.init)
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }
}
