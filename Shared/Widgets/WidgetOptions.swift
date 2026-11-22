import SwiftUI
import CalendarCore

/// Plain value snapshot of `TempoWidgetIntent`, so views never touch App Intents types.
struct WidgetOptions: Equatable {
    var daysAhead = 7, maxEvents = 0
    var showAllDay = true, showLocation = true, showCalendarName = false, showMeetingIcon = true, showFollowing = true
    var density: WidgetDensity = .comfortable
    var colorStyle: WidgetColorStyle = .calendar
    var tint: WidgetTint = .blue
    var background: WidgetBackgroundStyle = .system
    var timeFormat: WidgetTimeFormat = .system
    var countdown: WidgetCountdownStyle = .timer
    var inlineStyle: WidgetInlineStyle = .smart
    var showWeekNumbers = false
    var autoFitHours = true, fromHour = 8, toHour = 20, showNowLine = true

    static let `default` = WidgetOptions()

    init() {}
    init(_ i: TempoWidgetIntent) {
        daysAhead = i.daysAhead; maxEvents = i.maxEvents
        showAllDay = i.showAllDay; showLocation = i.showLocation; showCalendarName = i.showCalendarName
        showMeetingIcon = i.showMeetingIcon; showFollowing = i.showFollowing
        density = i.density; colorStyle = i.colorStyle; tint = i.tint; background = i.background
        timeFormat = i.timeFormat; countdown = i.countdown; inlineStyle = i.inlineStyle
        showWeekNumbers = i.showWeekNumbers
        autoFitHours = i.autoFitHours; fromHour = i.fromHour; toHour = max(i.toHour, i.fromHour + 2); showNowLine = i.showNowLine
    }

    var isCompact: Bool { density == .compact }
    var rowHeight: CGFloat { isCompact ? 15 : 19 }

    var tintColor: Color {
        switch tint {
        case .blue: .blue; case .red: .red; case .orange: .orange; case .yellow: .yellow; case .green: .green
        case .mint: .mint; case .teal: .teal; case .indigo: .indigo; case .purple: .purple; case .pink: .pink
        }
    }

    func color(_ c: RGBA) -> Color {
        switch colorStyle {
        case .calendar: Color(c)
        case .tint: tintColor
        case .monochrome: .primary
        }
    }

    func time(_ d: Date) -> String {
        switch timeFormat {
        case .system: d.formatted(.dateTime.hour().minute())
        case .h12: d.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_US")))
        case .h24: d.formatted(.dateTime.hour().minute().locale(Locale(identifier: "en_GB")))
        }
    }

    func window(_ e: EventItem) -> String { e.isAllDay ? "All day" : "\(time(e.start)) – \(time(e.end))" }

    func filter(_ events: [EventItem]) -> [EventItem] { showAllDay ? events : events.filter { !$0.isAllDay } }
}

/// Countdown text honouring the chosen style. `.timer` ticks live without timeline entries.
struct CountdownText: View {
    let date: Date
    let style: WidgetCountdownStyle
    var body: some View {
        switch style {
        case .timer: Text(date, style: .timer).monospacedDigit()
        case .minutes: Text(date, style: .relative)
        case .off: EmptyView()
        }
    }
}

extension View {
    /// Applies the user's chosen widget background.
    func tempoBackground(_ o: WidgetOptions) -> some View {
        containerBackground(for: .widget) {
            switch o.background {
            case .system: Rectangle().fill(.fill.tertiary)
            case .tinted: o.tintColor.opacity(0.18)
            case .clear: Color.clear
            }
        }
    }
}
