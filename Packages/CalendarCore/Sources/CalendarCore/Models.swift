import Foundation
import CoreGraphics

public struct RGBA: Codable, Hashable, Sendable {
    public var r, g, b, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public static let fallback = RGBA(r: 0.0, g: 0.48, b: 1.0)

    public init(cgColor: CGColor?) {
        guard let cgColor,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let c = cgColor.converted(to: space, intent: .defaultIntent, options: nil),
              let comps = c.components, comps.count >= 3
        else { self = .fallback; return }
        self.init(r: comps[0], g: comps[1], b: comps[2], a: comps.count > 3 ? comps[3] : 1)
    }
}

public struct CalendarInfo: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var source: String
    public var color: RGBA
    public var allowsModify: Bool
    public var isReminderList: Bool
    public var isSubscribed: Bool
    public init(id: String, title: String, source: String, color: RGBA, allowsModify: Bool, isReminderList: Bool = false, isSubscribed: Bool = false) {
        self.id = id; self.title = title; self.source = source; self.color = color
        self.allowsModify = allowsModify; self.isReminderList = isReminderList; self.isSubscribed = isSubscribed
    }
}

/// Value-type snapshot of an `EKEvent`: Sendable, Codable, safe to hand to widgets and views.
public struct EventItem: Identifiable, Hashable, Sendable, Codable {
    public var id: String            // unique per occurrence
    public var eventID: String       // EKEvent.eventIdentifier (shared by recurrences)
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var calendarID: String
    public var calendarTitle: String
    public var color: RGBA
    public var meetingLink: MeetingLink?
    public var hasRecurrence: Bool
    public var canModify: Bool
    /// First ~500 characters of the event's notes (read-only; widgets never show it).
    public var notes: String?
    /// Number of invited people (nil when the event has no attendees).
    public var attendeeCount: Int?

    public init(id: String? = nil, eventID: String, title: String, start: Date, end: Date, isAllDay: Bool = false,
                location: String? = nil, calendarID: String = "", calendarTitle: String = "", color: RGBA = .fallback,
                meetingLink: MeetingLink? = nil, hasRecurrence: Bool = false, canModify: Bool = true, notes: String? = nil, attendeeCount: Int? = nil) {
        self.id = id ?? "\(eventID)|\(Int(start.timeIntervalSince1970))"
        self.eventID = eventID; self.title = title; self.start = start; self.end = end
        self.isAllDay = isAllDay; self.location = location; self.calendarID = calendarID
        self.calendarTitle = calendarTitle; self.color = color; self.meetingLink = meetingLink
        self.hasRecurrence = hasRecurrence; self.canModify = canModify; self.notes = notes; self.attendeeCount = attendeeCount
    }

    public var interval: DateInterval { DateInterval(start: start, end: max(end, start)) }
}

public struct ReminderItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var due: Date?
    public var isCompleted: Bool
    public var priority: Int
    public var listTitle: String
    public var color: RGBA
    public init(id: String, title: String, due: Date?, isCompleted: Bool, priority: Int, listTitle: String, color: RGBA) {
        self.id = id; self.title = title; self.due = due; self.isCompleted = isCompleted
        self.priority = priority; self.listTitle = listTitle; self.color = color
    }
}

public enum AccessState: Sendable { case notDetermined, denied, restricted, writeOnly, full }
