import SwiftUI
import CalendarCore

extension Color {
    init(_ c: RGBA) { self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }
}

extension EventItem {
    var timeRangeText: String { isAllDay ? "All day" : "\(start.timeText) – \(end.timeText)" }
}

extension Calendar {
    /// Dates for a month grid (leading/trailing days padded with nil), honouring `firstWeekday`.
    func monthGrid(for date: Date) -> [Date?] {
        guard let month = dateInterval(of: .month, for: date),
              let days = range(of: .day, in: .month, for: date) else { return [] }
        let lead = (component(.weekday, from: month.start) - firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        cells += days.compactMap { self.date(byAdding: .day, value: $0 - 1, to: month.start) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    var orderedShortWeekdaySymbols: [String] {
        let s = veryShortStandaloneWeekdaySymbols
        return Array(s[(firstWeekday - 1)...] + s[..<(firstWeekday - 1)])
    }
}
