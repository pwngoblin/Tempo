import WidgetKit
import SwiftUI
import CalendarCore

/// Shown when calendar access has not been granted yet.
struct NoAccessView: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar.badge.exclamationmark")
            Text("Open Tempo to allow calendar access").font(.caption2).multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
    }
}

/// Color bar. `widgetAccentable` makes it take the tint in accented/tinted modes instead of clashing.
struct ColorBar: View {
    let color: Color
    var width: CGFloat = 3
    var body: some View {
        RoundedRectangle(cornerRadius: width / 2).fill(color).frame(width: width).widgetAccentable()
    }
}

/// One dense agenda line: bar + time + title (+ optional location / calendar / meeting glyph).
struct DenseEventLine: View {
    let event: EventItem
    let options: WidgetOptions
    var body: some View {
        HStack(spacing: 5) {
            ColorBar(color: options.color(event.color))
            Text(event.isAllDay ? "All day" : options.time(event.start))
                .font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
                .frame(minWidth: 30, alignment: .leading)
            Text(event.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            if options.showMeetingIcon, event.meetingLink != nil {
                Image(systemName: "video.fill").font(.system(size: 8)).foregroundStyle(.secondary)
            }
            if !options.isCompact {
                let extra = [options.showLocation ? event.location : nil, options.showCalendarName ? event.calendarTitle : nil].compactMap { $0 }.joined(separator: " · ")
                if !extra.isEmpty { Text(extra).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
        .frame(height: options.rowHeight)
        .accessibilityElement(children: .combine)
    }
}

enum AgendaLine: Identifiable {
    case header(String), event(EventItem)
    var id: String {
        switch self { case .header(let t): "h-\(t)"; case .event(let e): e.id }
    }
}

enum AgendaBuilder {
    /// Flattens upcoming events into header + event lines, capped at `maxLines` lines and `maxEvents` events.
    static func lines(_ events: [EventItem], from now: Date, maxLines: Int, maxEvents: Int = 0, calendar: Calendar = .current) -> [AgendaLine] {
        var out: [AgendaLine] = []
        var count = 0
        let upcoming = events.filter { $0.end > now }.sorted { $0.start < $1.start }
        var lastDay: Date?
        for e in upcoming {
            if maxEvents > 0, count >= maxEvents { break }
            let day = calendar.startOfDay(for: max(e.start, now))
            if day != lastDay {
                guard out.count + 2 <= maxLines else { break }
                let label = calendar.isDateInToday(day) ? "Today" : calendar.isDateInTomorrow(day) ? "Tomorrow" : day.formatted(.dateTime.weekday(.abbreviated).day())
                out.append(.header(label)); lastDay = day
            }
            guard out.count < maxLines else { break }
            out.append(.event(e)); count += 1
        }
        return out
    }
}

struct AgendaListView: View {
    let events: [EventItem]
    let now: Date
    let options: WidgetOptions
    var body: some View {
        GeometryReader { geo in
            let maxLines = max(Int(geo.size.height / options.rowHeight), 1)
            let lines = AgendaBuilder.lines(events, from: now, maxLines: maxLines, maxEvents: options.maxEvents)
            VStack(alignment: .leading, spacing: 0) {
                if lines.isEmpty {
                    Label("Nothing coming up", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(lines) { line in
                    switch line {
                    case .header(let t):
                        Text(t.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                            .frame(height: options.rowHeight, alignment: .bottom)
                    case .event(let e): DenseEventLine(event: e, options: options)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, alignment: .leading)
        }
    }
}
