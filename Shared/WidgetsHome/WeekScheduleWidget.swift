import WidgetKit
import SwiftUI
import CalendarCore

/// Seven-day block view: busy time is coloured, open gaps stay empty.
struct WeekScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoWeekSchedule", intent: TempoWidgetIntent.self, provider: TempoProvider()) { entry in
            WeekScheduleView(entry: entry).widgetURL(DeepLink.today.url).tempoBackground(entry.options)
        }
        .configurationDisplayName("Week Schedule")
        .description("See busy blocks and open gaps across the next 7 days.")
        .supportedFamilies([.systemLarge])
    }
}

struct WeekScheduleView: View {
    let entry: TempoEntry
    private let cal = Calendar.tempo
    private var o: WidgetOptions { entry.options }

    var body: some View {
        if entry.access != .full { NoAccessView() }
        else {
            let today = cal.startOfDay(for: entry.date)
            let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
            let (startHour, endHour) = hourRange(days)
            VStack(spacing: 4) {
                HStack {
                    Text("Next 7 days").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text(entry.set.name).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    VStack(spacing: 0) {   // hour gutter
                        Color.clear.frame(height: 22)
                        GeometryReader { geo in
                            let step = max(((endHour - startHour) / 4), 1)
                            ForEach(Array(stride(from: startHour, to: endHour, by: step)), id: \.self) { h in
                                Text(String(format: "%02d", h)).font(.system(size: 8).monospacedDigit()).foregroundStyle(.secondary)
                                    .position(x: 9, y: geo.size.height * CGFloat(h - startHour) / CGFloat(endHour - startHour))
                            }
                        }
                    }.frame(width: 20)
                    ForEach(days, id: \.self) { day in dayColumn(day, startHour, endHour) }
                }
            }
        }
    }

    private func hourRange(_ days: [Date]) -> (Int, Int) {
        if !o.autoFitHours { return (o.fromHour, min(o.toHour, 24)) }
        var lo = 8, hi = 19
        for e in entry.events where !e.isAllDay {
            guard days.contains(where: { cal.isDate($0, inSameDayAs: e.start) }) else { continue }
            lo = min(lo, cal.component(.hour, from: e.start))
            let h = cal.component(.hour, from: e.end) + (cal.component(.minute, from: e.end) > 0 ? 1 : 0)
            hi = max(hi, cal.isDate(e.end, inSameDayAs: e.start) ? h : 24)
        }
        return (max(lo, 0), min(max(hi, lo + 4), 24))
    }

    private func dayColumn(_ day: Date, _ startHour: Int, _ endHour: Int) -> some View {
        let isToday = cal.isDateInToday(day)
        let dayEvents = Agenda.events(entry.events, on: day, calendar: cal)
        let span = Double(endHour - startHour) * 3600
        let origin = cal.date(byAdding: .hour, value: startHour, to: day)!
        return VStack(spacing: 2) {
            VStack(spacing: 0) {
                Text(day, format: .dateTime.weekday(.narrow)).font(.system(size: 8)).foregroundStyle(.secondary)
                Text("\(cal.component(.day, from: day))").font(.system(size: 11, weight: isToday ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(isToday ? Color.white : .primary)
                    .frame(width: 18, height: 16).background { if isToday { Circle().fill(o.colorStyle == .tint ? o.tintColor : .red).widgetAccentable() } }
            }.frame(height: 20)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 3).fill(.quaternary.opacity(0.5))
                    ForEach(Agenda.layout(dayEvents)) { p in
                        let s = max(p.event.start, origin), e = min(p.event.end, origin.addingTimeInterval(span))
                        if e > s {
                            let w = geo.size.width / CGFloat(p.columns)
                            RoundedRectangle(cornerRadius: 2).fill(o.color(p.event.color)).widgetAccentable()
                                .frame(width: max(w - 1, 2), height: max(geo.size.height * e.timeIntervalSince(s) / span, 3))
                                .offset(x: w * CGFloat(p.column), y: geo.size.height * s.timeIntervalSince(origin) / span)
                        }
                    }
                    if o.showNowLine, isToday, entry.date >= origin, entry.date <= origin.addingTimeInterval(span) {
                        Rectangle().fill(.red).frame(height: 1).offset(y: geo.size.height * entry.date.timeIntervalSince(origin) / span)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 1)
        .widgetURL(DeepLink.day(day).url)
    }
}
