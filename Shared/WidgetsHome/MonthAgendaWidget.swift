import WidgetKit
import SwiftUI
import CalendarCore

/// Split view: month grid with colour dots on the left, dense agenda on the right.
struct MonthAgendaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoMonthAgenda", intent: TempoWidgetIntent.self, provider: TempoProvider()) { entry in
            MonthAgendaView(entry: entry).widgetURL(DeepLink.today.url).tempoBackground(entry.options)
        }
        .configurationDisplayName("Month + Agenda")
        .description("Month grid with event dots next to your upcoming events.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct MonthAgendaView: View {
    let entry: TempoEntry
    var body: some View {
        if entry.access != .full { NoAccessView() }
        else {
            HStack(alignment: .top, spacing: 10) {
                MonthGridView(entry: entry).frame(maxWidth: .infinity)
                Rectangle().fill(.quaternary).frame(width: 0.5)
                AgendaListView(events: entry.events, now: entry.date, options: entry.options).frame(maxWidth: .infinity)
            }
            .padding(10)
        }
    }
}

struct MonthGridView: View {
    let entry: TempoEntry
    var scale: CGFloat = 1
    private let cal = Calendar.tempo
    private var o: WidgetOptions { entry.options }

    var body: some View {
        let cells = cal.monthGrid(for: entry.date)
        let rows = cells.count / 7
        let byDay = Agenda.byDay(entry.events, calendar: cal)
        VStack(spacing: 2) {
            Text(entry.date, format: .dateTime.month(.wide)).font(.system(size: 11 * scale, weight: .bold)).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                if o.showWeekNumbers { Color.clear.frame(width: 14 * scale) }
                ForEach(Array(cal.orderedShortWeekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.system(size: 8 * scale)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            GeometryReader { geo in
                let rowH = geo.size.height / CGFloat(max(rows, 1))
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { r in
                        HStack(spacing: 0) {
                            if o.showWeekNumbers {
                                let anyDay = (0..<7).compactMap { cells[r * 7 + $0] }.first
                                Text(anyDay.map { "\(cal.component(.weekOfYear, from: $0))" } ?? "")
                                    .font(.system(size: 7 * scale).monospacedDigit()).foregroundStyle(.tertiary).frame(width: 14 * scale)
                            }
                            ForEach(0..<7, id: \.self) { c in
                                if let d = cells[r * 7 + c] { cell(d, byDay[cal.startOfDay(for: d)] ?? []) }
                                else { Color.clear.frame(maxWidth: .infinity) }
                            }
                        }.frame(height: rowH)
                    }
                }
            }
        }
    }

    private func cell(_ d: Date, _ events: [EventItem]) -> some View {
        let isToday = cal.isDate(d, inSameDayAs: entry.date)
        var colors: [RGBA] = []
        for e in events where !colors.contains(e.color) && colors.count < 3 { colors.append(e.color) }
        return VStack(spacing: 1) {
            Text("\(cal.component(.day, from: d))")
                .font(.system(size: 10 * scale, weight: isToday ? .bold : .regular).monospacedDigit())
                .foregroundStyle(isToday ? Color.white : .primary)
                .frame(width: 17 * scale, height: 17 * scale)
                .background { if isToday { Circle().fill(o.colorStyle == .tint ? o.tintColor : .red).widgetAccentable() } }
            HStack(spacing: 1.5) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, c in Circle().fill(o.color(c)).frame(width: 3.5 * scale, height: 3.5 * scale).widgetAccentable() }
            }.frame(height: 4 * scale)
        }
        .frame(maxWidth: .infinity)
        .widgetURL(DeepLink.day(d).url)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(d.formatted(date: .complete, time: .omitted) + (events.isEmpty ? "" : ", \(events.count) events"))
    }
}
