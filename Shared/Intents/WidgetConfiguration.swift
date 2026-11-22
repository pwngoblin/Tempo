import AppIntents
import CalendarCore

// MARK: - Option enums (each becomes a picker in the widget's "Edit Widget" sheet)

enum WidgetDensity: String, AppEnum {
    case compact, comfortable
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Density"
    static let caseDisplayRepresentations: [WidgetDensity: DisplayRepresentation] = [
        .compact: "Compact", .comfortable: "Comfortable"]
}

enum WidgetColorStyle: String, AppEnum {
    case calendar, tint, monochrome
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Colors"
    static let caseDisplayRepresentations: [WidgetColorStyle: DisplayRepresentation] = [
        .calendar: "Calendar colors", .tint: "Single tint", .monochrome: "Monochrome"]
}

enum WidgetTint: String, AppEnum {
    case blue, red, orange, yellow, green, mint, teal, indigo, purple, pink
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Tint"
    static let caseDisplayRepresentations: [WidgetTint: DisplayRepresentation] = [
        .blue: "Blue", .red: "Red", .orange: "Orange", .yellow: "Yellow", .green: "Green",
        .mint: "Mint", .teal: "Teal", .indigo: "Indigo", .purple: "Purple", .pink: "Pink"]
}

enum WidgetTimeFormat: String, AppEnum {
    case system, h12, h24
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Time format"
    static let caseDisplayRepresentations: [WidgetTimeFormat: DisplayRepresentation] = [
        .system: "System", .h12: "12-hour", .h24: "24-hour"]
}

enum WidgetBackgroundStyle: String, AppEnum {
    case system, tinted, clear
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Background"
    static let caseDisplayRepresentations: [WidgetBackgroundStyle: DisplayRepresentation] = [
        .system: "System", .tinted: "Tinted", .clear: "None"]
}

enum WidgetCountdownStyle: String, AppEnum {
    case timer, minutes, off
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Countdown"
    static let caseDisplayRepresentations: [WidgetCountdownStyle: DisplayRepresentation] = [
        .timer: "Live timer (12:34)", .minutes: "Relative (12 min)", .off: "Hidden"]
}

enum WidgetInlineStyle: String, AppEnum {
    case smart, nextWithTime, countdown, freeBusy
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Inline text"
    static let caseDisplayRepresentations: [WidgetInlineStyle: DisplayRepresentation] = [
        .smart: "Smart", .nextWithTime: "Next · time", .countdown: "Next · countdown", .freeBusy: "Free / busy until"]
}

// MARK: - The one configuration intent shared by every Tempo widget and complication

/// Every widget uses this intent, so any option can be tuned on any widget. Options that don't apply
/// to a given widget or family are ignored (see docs/WIDGETS.md for the matrix).
struct TempoWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Customize"
    static let description = IntentDescription("Choose the calendar set, colors, density and what each widget shows.")

    // Content
    @Parameter(title: "Calendar Set", description: "Leave empty to follow the active set.")
    var set: CalendarSetEntity?
    @Parameter(title: "Days ahead", default: 7, inclusiveRange: (1, 14)) var daysAhead: Int
    @Parameter(title: "Max events (0 = fit to size)", default: 0, inclusiveRange: (0, 20)) var maxEvents: Int
    @Parameter(title: "All-day events", default: true) var showAllDay: Bool
    @Parameter(title: "Locations", default: true) var showLocation: Bool
    @Parameter(title: "Calendar names", default: false) var showCalendarName: Bool
    @Parameter(title: "Meeting icon", default: true) var showMeetingIcon: Bool
    @Parameter(title: "Following event", default: true) var showFollowing: Bool

    // Look
    @Parameter(title: "Density", default: .comfortable) var density: WidgetDensity
    @Parameter(title: "Colors", default: .calendar) var colorStyle: WidgetColorStyle
    @Parameter(title: "Tint", default: .blue) var tint: WidgetTint
    @Parameter(title: "Background", default: .system) var background: WidgetBackgroundStyle
    @Parameter(title: "Time format", default: .system) var timeFormat: WidgetTimeFormat

    // Next-event & complications
    @Parameter(title: "Countdown", default: .timer) var countdown: WidgetCountdownStyle
    @Parameter(title: "Inline text", default: .smart) var inlineStyle: WidgetInlineStyle

    // Month grid
    @Parameter(title: "Week numbers", default: false) var showWeekNumbers: Bool

    // Week schedule
    @Parameter(title: "Fit hours to events", default: true) var autoFitHours: Bool
    @Parameter(title: "Week grid from hour", default: 8, inclusiveRange: (0, 22)) var fromHour: Int
    @Parameter(title: "Week grid to hour", default: 20, inclusiveRange: (2, 24)) var toHour: Int
    @Parameter(title: "Now line", default: true) var showNowLine: Bool

    init() {}
}
