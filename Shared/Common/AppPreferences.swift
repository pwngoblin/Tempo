import SwiftUI
import Observation
import CalendarCore

// MARK: - Choices

enum ThemeChoice: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? { self == .system ? nil : (self == .light ? .light : .dark) }
}

enum AccentChoice: String, Codable, CaseIterable, Identifiable {
    case system, blue, red, orange, yellow, green, mint, teal, indigo, purple, pink, graphite
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .system: .accentColor
        case .blue: .blue; case .red: .red; case .orange: .orange; case .yellow: .yellow; case .green: .green
        case .mint: .mint; case .teal: .teal; case .indigo: .indigo; case .purple: .purple; case .pink: .pink
        case .graphite: .gray
        }
    }
}

enum TimeFormatChoice: String, Codable, CaseIterable, Identifiable {
    case system, h12, h24
    var id: String { rawValue }
    var title: String { self == .system ? "System" : self == .h12 ? "12-hour" : "24-hour" }
}

enum WeekStartChoice: Int, Codable, CaseIterable, Identifiable {
    case system = 0, sunday = 1, monday = 2, saturday = 7
    var id: Int { rawValue }
    var title: String { ["System", "Sunday", "Monday", "", "", "", "", "Saturday"][rawValue] }
    static var allCases: [WeekStartChoice] { [.system, .monday, .sunday, .saturday] }
}

enum BlockStyleChoice: String, Codable, CaseIterable, Identifiable {
    case tinted, solid, outlined
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum DensityChoice: String, Codable, CaseIterable, Identifiable {
    case compact, comfortable, spacious
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var rowPadding: CGFloat { self == .compact ? 0 : self == .comfortable ? 3 : 8 }
}

enum MenuBarFormatChoice: String, Codable, CaseIterable, Identifiable {
    case compact, long
    var id: String { rawValue }
    var title: String { self == .compact ? "12m" : "12 min" }
}

// MARK: - Preferences value

/// Everything the user can tune. Decoding is tolerant: fields added in later versions fall back to defaults
/// instead of wiping saved settings.
struct AppPrefs: Codable, Equatable {
    // Appearance
    var theme: ThemeChoice = .system
    var accent: AccentChoice = .system
    var timeFormat: TimeFormatChoice = .system
    var weekStart: WeekStartChoice = .system
    var showWeekNumbers = false
    // Layout
    var density: DensityChoice = .comfortable
    var blockStyle: BlockStyleChoice = .tinted
    var hourHeightScale = 1.0              // 0.7 … 1.8
    var scrollToHour = 8                   // where day/week grids open when not today
    var workWeekOnly = false               // week view shows Mon–Fri
    var showAllDayStrip = true
    var showEndTime = true
    var showLocation = true
    var showMeetingBadge = true
    // Agenda & views
    var agendaDays = 14
    var showReminders = true
    var defaultViewPhone = "agenda"        // agenda | week | month
    var defaultViewMac = "week"            // day | week | month
    // New events
    var defaultDurationMinutes = 60
    var preferredCalendarID: String?
    var haptics = true
    // Menu bar (macOS)
    var menuBarEnabled = true
    var menuBarShowTitle = true
    var menuBarMaxTitle = 22
    var menuBarFormat: MenuBarFormatChoice = .compact
    var joinLeadMinutes = 15

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ d: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? d }
        theme = v(.theme, theme); accent = v(.accent, accent); timeFormat = v(.timeFormat, timeFormat)
        weekStart = v(.weekStart, weekStart); showWeekNumbers = v(.showWeekNumbers, showWeekNumbers)
        density = v(.density, density); blockStyle = v(.blockStyle, blockStyle)
        hourHeightScale = min(max(v(.hourHeightScale, hourHeightScale), 0.7), 1.8)
        scrollToHour = min(max(v(.scrollToHour, scrollToHour), 0), 22)
        workWeekOnly = v(.workWeekOnly, workWeekOnly); showAllDayStrip = v(.showAllDayStrip, showAllDayStrip)
        showEndTime = v(.showEndTime, showEndTime); showLocation = v(.showLocation, showLocation)
        showMeetingBadge = v(.showMeetingBadge, showMeetingBadge)
        agendaDays = v(.agendaDays, agendaDays); showReminders = v(.showReminders, showReminders)
        defaultViewPhone = v(.defaultViewPhone, defaultViewPhone); defaultViewMac = v(.defaultViewMac, defaultViewMac)
        defaultDurationMinutes = min(max(v(.defaultDurationMinutes, defaultDurationMinutes), 5), 480)
        preferredCalendarID = try? c.decodeIfPresent(String.self, forKey: .preferredCalendarID)
        haptics = v(.haptics, haptics)
        menuBarEnabled = v(.menuBarEnabled, menuBarEnabled); menuBarShowTitle = v(.menuBarShowTitle, menuBarShowTitle)
        menuBarMaxTitle = min(max(v(.menuBarMaxTitle, menuBarMaxTitle), 8), 60)
        menuBarFormat = v(.menuBarFormat, menuBarFormat)
        joinLeadMinutes = min(max(v(.joinLeadMinutes, joinLeadMinutes), 1), 60)
    }

    static let key = "appPrefs.v1"
    static func load() -> AppPrefs {
        guard let data = AppGroup.defaults.data(forKey: key), let p = try? JSONDecoder().decode(AppPrefs.self, from: data) else { return AppPrefs() }
        return p
    }
    /// Changes that need a full re-layout of date-based views.
    var layoutKey: String { "\(weekStart.rawValue)-\(timeFormat.rawValue)-\(density.rawValue)" }
    func save() { if let d = try? JSONEncoder().encode(self) { AppGroup.defaults.set(d, forKey: Self.key) } }
}

/// Thread-safe-enough read of the latest prefs for non-UI code (formatters, widget providers).
enum PrefsSnapshot {
    nonisolated(unsafe) static var current = AppPrefs.load()
    static func reload() { current = AppPrefs.load() }
}

/// Observable singleton: views read `PrefsStore.shared.values.x` in `body` and re-render when it changes.
@MainActor @Observable
final class PrefsStore {
    static let shared = PrefsStore()
    var values: AppPrefs { didSet { values.save(); PrefsSnapshot.current = values } }
    private init() { values = AppPrefs.load() }
    func reset() { values = AppPrefs() }
    /// Pick up changes written by another process (main app <-> menu-bar helper share the App Group).
    func reloadFromDisk() { let v = AppPrefs.load(); if v != values { values = v } }
}

// MARK: - Helpers used across the UI

extension Calendar {
    /// `Calendar.current` honouring the user's "first day of week" preference.
    static var tempo: Calendar {
        var c = Calendar.current
        let w = PrefsSnapshot.current.weekStart.rawValue
        if w != 0 { c.firstWeekday = w }
        return c
    }
}

extension Date {
    /// Short time honouring the user's 12/24-hour preference.
    var timeText: String {
        switch PrefsSnapshot.current.timeFormat {
        case .system: formatted(.dateTime.hour().minute())
        case .h12: formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_US")))
        case .h24: formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_GB")))
        }
    }
    /// Hour-only label for grids ("9", "14", "2 PM").
    var hourText: String {
        switch PrefsSnapshot.current.timeFormat {
        case .system: formatted(.dateTime.hour())
        case .h12: formatted(.dateTime.hour().locale(Locale(identifier: "en_US")))
        case .h24: formatted(.dateTime.hour().locale(Locale(identifier: "en_GB")))
        }
    }
}

extension View {
    /// Haptic feedback that respects the user's Haptics switch.
    func tempoHaptic<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View {
        sensoryFeedback(trigger: trigger) { _, _ in PrefsSnapshot.current.haptics ? feedback : nil }
    }

    /// Event block look: tinted (default), solid, or outlined.
    func eventBlock(_ color: Color, style: BlockStyleChoice, corner: CGFloat = 6) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return self
            .foregroundStyle(style == .solid ? Color.white : Color.primary)
            .background {
                switch style {
                case .tinted: shape.fill(color.opacity(0.2))
                case .solid: shape.fill(color)
                case .outlined: shape.fill(Color.clear)
                }
            }
            .overlay { if style == .outlined { shape.strokeBorder(color, lineWidth: 1.5) } }
            .overlay(alignment: .leading) {
                if style != .outlined { Rectangle().fill(style == .solid ? Color.white.opacity(0.55) : color).frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 1.5)) }
            }
            .clipShape(shape)
    }
}
