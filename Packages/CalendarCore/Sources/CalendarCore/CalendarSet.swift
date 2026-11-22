import Foundation

/// A stable reference to an `EKCalendar`. `id` is device-local, so title+source is kept as a
/// fallback for matching the same calendar on another device (e.g. Mac <-> iPhone <-> Watch).
public struct CalendarRef: Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var source: String
    public init(id: String, title: String, source: String) { self.id = id; self.title = title; self.source = source }
    public init(_ info: CalendarInfo) { self.init(id: info.id, title: info.title, source: info.source) }
}

public struct CalendarSet: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var includesAll: Bool
    public var calendars: [CalendarRef]

    public static let allID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    public static let all = CalendarSet(id: allID, name: "All", symbol: "calendar", includesAll: true, calendars: [])

    public init(id: UUID = UUID(), name: String, symbol: String = "folder", includesAll: Bool = false, calendars: [CalendarRef] = []) {
        self.id = id; self.name = name; self.symbol = symbol; self.includesAll = includesAll; self.calendars = calendars
    }

    public func contains(_ calendar: CalendarInfo) -> Bool {
        includesAll || calendars.contains { $0.id == calendar.id || ($0.title == calendar.title && $0.source == calendar.source) }
    }
}

/// Persists Calendar Sets in the App Group (shared with widgets) and mirrors the definitions to
/// iCloud key-value storage so Mac / iPhone / Watch share them. The *active* set stays per device.
public final class CalendarSetStore: @unchecked Sendable {
    private struct Payload: Codable { var sets: [CalendarSet]; var updatedAt: Date }

    private let defaults: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore?
    private let setsKey = "calendarSets.v1"
    private let activeKey = "activeCalendarSet.v1"

    public init(defaults: UserDefaults = AppGroup.defaults, cloud: NSUbiquitousKeyValueStore? = nil) {
        self.defaults = defaults; self.cloud = cloud
    }

    /// "All" first, then user-defined sets.
    public var sets: [CalendarSet] { [.all] + customSets }

    public var customSets: [CalendarSet] {
        guard let data = defaults.data(forKey: setsKey), let p = try? decoder.decode(Payload.self, from: data) else { return [] }
        return p.sets.filter { $0.id != CalendarSet.allID }
    }

    public var activeID: UUID {
        get { defaults.string(forKey: activeKey).flatMap(UUID.init(uuidString:)) ?? CalendarSet.allID }
        set { defaults.set(newValue.uuidString, forKey: activeKey) }
    }

    public var active: CalendarSet { sets.first { $0.id == activeID } ?? .all }

    public func save(_ custom: [CalendarSet]) {
        let payload = Payload(sets: custom.filter { $0.id != CalendarSet.allID }, updatedAt: Date())
        guard let data = try? encoder.encode(payload) else { return }
        defaults.set(data, forKey: setsKey)
        cloud?.set(data, forKey: setsKey)
        cloud?.synchronize()
        if !sets.contains(where: { $0.id == activeID }) { activeID = CalendarSet.allID }
    }

    /// Cycles the active set (All -> Work -> Personal -> All ...). Returns the new active set.
    @discardableResult
    public func cycle(by step: Int = 1) -> CalendarSet {
        let all = sets
        let idx = all.firstIndex { $0.id == activeID } ?? 0
        let next = all[((idx + step) % all.count + all.count) % all.count]
        activeID = next.id
        return next
    }

    /// Adopt the iCloud copy if it is newer. Returns true when local data changed.
    @discardableResult
    public func pullFromCloud() -> Bool {
        guard let data = cloud?.data(forKey: setsKey) else { return false }
        return importPayload(data)
    }

    /// Serialized set definitions (sent iPhone → Watch over WatchConnectivity).
    public func exportPayload() -> Data? { defaults.data(forKey: setsKey) }

    /// Adopt a payload from another device if it is newer than the local one.
    @discardableResult
    public func importPayload(_ data: Data) -> Bool {
        guard let remote = try? decoder.decode(Payload.self, from: data) else { return false }
        let localDate = defaults.data(forKey: setsKey).flatMap { try? decoder.decode(Payload.self, from: $0) }?.updatedAt ?? .distantPast
        guard remote.updatedAt > localDate else { return false }
        defaults.set(data, forKey: setsKey)
        if !sets.contains(where: { $0.id == activeID }) { activeID = CalendarSet.allID }
        return true
    }

    private var encoder: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
    private var decoder: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}
