import Foundation
import CalendarCore

/// Text shown in the macOS status bar ("GRC Sync · 12m"). Shared by the menu-bar helper and the Settings preview.
enum MenuBarFormat {
    static func text(_ events: [EventItem], now: Date, prefs: AppPrefs) -> String? {
        let long = prefs.menuBarFormat == .long
        func line(_ e: EventItem, _ interval: TimeInterval, suffix: String) -> String {
            let t = compact(interval, long: long) + suffix
            return prefs.menuBarShowTitle ? "\(trim(e.title, prefs.menuBarMaxTitle)) · \(t)" : t
        }
        if let cur = Agenda.current(events, at: now) { return line(cur, cur.end.timeIntervalSince(now), suffix: " left") }
        if let next = Agenda.next(events, after: now) { return line(next, next.start.timeIntervalSince(now), suffix: "") }
        return nil
    }

    static func trim(_ s: String, _ max: Int) -> String { s.count > max ? String(s.prefix(max - 1)) + "…" : s }

    static func compact(_ interval: TimeInterval, long: Bool) -> String {
        let m = Swift.max(Int((interval / 60).rounded(.up)), 1)
        if m < 60 { return long ? "\(m) min" : "\(m)m" }
        let h = m / 60, r = m % 60
        if long { return r == 0 ? "\(h) h" : "\(h) h \(r) min" }
        return r == 0 ? "\(h)h" : "\(h)h \(r)m"
    }
}
