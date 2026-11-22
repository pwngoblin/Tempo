import WidgetKit
import SwiftUI
import CalendarCore

// MARK: - Agenda (small / medium / large)

/// A clean list of what's coming up, grouped by day. Fully driven by `TempoWidgetIntent`.
struct AgendaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoAgenda", intent: TempoWidgetIntent.self, provider: TempoProvider()) { entry in
            AgendaWidgetView(entry: entry).widgetURL(DeepLink.today.url).tempoBackground(entry.options)
        }
        .configurationDisplayName("Agenda")
        .description("Your upcoming events, grouped by day.")
        .supportedFamilies(Self.families)
    }
    static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

struct AgendaWidgetView: View {
    let entry: TempoEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if entry.access != .full { NoAccessView() }
        else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.date, format: .dateTime.weekday(.wide)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.red).textCase(.uppercase)
                    Text(entry.date, format: .dateTime.day()).font(.system(size: family == .systemSmall ? 22 : 26, weight: .light))
                    Spacer()
                    if family != .systemSmall { Text(entry.set.name).font(.system(size: 10)).foregroundStyle(.secondary) }
                }
                AgendaListView(events: entry.events, now: entry.date, options: entry.options)
            }
        }
    }
}

// MARK: - Month (large)

struct MonthWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoMonth", intent: TempoWidgetIntent.self, provider: TempoProvider()) { entry in
            Group {
                if entry.access != .full { NoAccessView() } else { MonthGridView(entry: entry, scale: 1.35) }
            }
            .widgetURL(DeepLink.today.url).tempoBackground(entry.options)
        }
        .configurationDisplayName("Month")
        .description("A full month with colored event dots. Tap a day to open it.")
        .supportedFamilies(Self.families)
    }
    static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemLarge, .systemExtraLarge]
        #else
        [.systemLarge]
        #endif
    }
}

// MARK: - Day timeline (medium / large)

struct DayTimelineWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoDayTimeline", intent: TempoWidgetIntent.self, provider: TempoProvider()) { entry in
            DayTimelineView(entry: entry).widgetURL(DeepLink.today.url).tempoBackground(entry.options)
        }
        .configurationDisplayName("Today Timeline")
        .description("Today as an hour-by-hour timeline with a now line.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DayTimelineView: View {
    let entry: TempoEntry
    private let cal = Calendar.tempo
    private var o: WidgetOptions { entry.options }

    var body: some View {
        if entry.access != .full { NoAccessView() }
        else {
            let day = cal.startOfDay(for: entry.date)
            let events = Agenda.events(entry.events, on: day, calendar: cal)
            let timed = events.filter { !$0.isAllDay }
            let (lo, hi) = range(timed)
            let span = Double(hi - lo) * 3600
            let origin = cal.date(byAdding: .hour, value: lo, to: day)!
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.date, format: .dateTime.weekday(.wide).day().month(.abbreviated)).font(.system(size: 12, weight: .semibold))
                    Spacer()
                    let allDay = events.filter(\.isAllDay)
                    if let first = allDay.first { Label(allDay.count > 1 ? "\(first.title) +\(allDay.count - 1)" : first.title, systemImage: "sun.max").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1) }
                }
                GeometryReader { geo in
                    let gutter: CGFloat = 22
                    let width = geo.size.width - gutter
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(stride(from: lo, to: hi, by: max((hi - lo) / 6, 1))), id: \.self) { h in
                            let y = geo.size.height * CGFloat(h - lo) / CGFloat(hi - lo)
                            Text(cal.date(bySettingHour: h, minute: 0, second: 0, of: day)!.hourText).font(.system(size: 8).monospacedDigit()).foregroundStyle(.secondary).position(x: 9, y: y + 4)
                            Rectangle().fill(.quaternary).frame(width: width, height: 0.5).offset(x: gutter, y: y)
                        }
                        ForEach(Agenda.layout(timed)) { p in
                            let s = max(p.event.start, origin), e = min(p.event.end, origin.addingTimeInterval(span))
                            if e > s {
                                let w = width / CGFloat(p.columns)
                                let h = max(geo.size.height * e.timeIntervalSince(s) / span - 1, 8)
                                RoundedRectangle(cornerRadius: 4).fill(o.color(p.event.color).opacity(0.28)).widgetAccentable()
                                    .overlay(alignment: .topLeading) {
                                        Text(p.event.title).font(.system(size: 9, weight: .semibold)).lineLimit(h > 22 ? 2 : 1).padding(.horizontal, 4).padding(.top, 1)
                                    }
                                    .overlay(alignment: .leading) { Rectangle().fill(o.color(p.event.color)).frame(width: 2.5).widgetAccentable() }
                                    .frame(width: max(w - 2, 4), height: h)
                                    .offset(x: gutter + w * CGFloat(p.column), y: geo.size.height * s.timeIntervalSince(origin) / span)
                            }
                        }
                        if o.showNowLine, entry.date >= origin, entry.date <= origin.addingTimeInterval(span) {
                            Rectangle().fill(.red).frame(width: width, height: 1).offset(x: gutter, y: geo.size.height * entry.date.timeIntervalSince(origin) / span)
                        }
                    }
                }
            }
        }
    }

    private func range(_ timed: [EventItem]) -> (Int, Int) {
        if !o.autoFitHours { return (o.fromHour, min(o.toHour, 24)) }
        var lo = 8, hi = 18
        for e in timed {
            lo = min(lo, cal.component(.hour, from: e.start))
            hi = max(hi, cal.isDate(e.end, inSameDayAs: e.start) ? cal.component(.hour, from: e.end) + (cal.component(.minute, from: e.end) > 0 ? 1 : 0) : 24)
        }
        return (max(lo, 0), min(max(hi, lo + 4), 24))
    }
}
