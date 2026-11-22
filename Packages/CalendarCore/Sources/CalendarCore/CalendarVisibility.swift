import Foundation

/// Which calendars the user has hidden everywhere in Tempo (apps *and* widgets; stored in the App Group).
/// Hiding only filters what Tempo displays; it never changes the calendars themselves.
public final class CalendarVisibility: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "hiddenCalendars.v1"
    public init(defaults: UserDefaults = AppGroup.defaults) { self.defaults = defaults }

    public var hidden: Set<String> {
        get { Set(defaults.stringArray(forKey: key) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: key) }
    }
    public func setHidden(_ id: String, _ isHidden: Bool) {
        var h = hidden
        if isHidden { h.insert(id) } else { h.remove(id) }
        hidden = h
    }
}
