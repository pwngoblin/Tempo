import WidgetKit
import SwiftUI
import CalendarCore

#if !os(macOS)   // accessory families don't exist on macOS

/// Lock Screen / watch complication: how much of today is left, and what's next.
struct TodayGlanceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoTodayGlance", intent: TempoWidgetIntent.self, provider: TempoProvider()) { entry in
            TodayGlanceView(entry: entry).widgetURL(DeepLink.today.url)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Today at a Glance")
        .description("Events left today as a ring, with what's next.")
        .supportedFamilies(Self.families)
    }
    static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline]
        #else
        [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

struct TodayGlanceView: View {
    let entry: TempoEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.isLuminanceReduced) private var reduced
    private var o: WidgetOptions { entry.options }

    private var today: [EventItem] { Agenda.events(entry.events, on: entry.date, calendar: .tempo).filter { !$0.isAllDay } }
    private var total: Int { today.count }
    private var remaining: [EventItem] { today.filter { $0.end > entry.date } }
    private var next: EventItem? { remaining.first { $0.start > entry.date } ?? remaining.first }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: total == 0 ? 1 : Double(total - remaining.count), in: 0...Double(max(total, 1))) {
                Image(systemName: "calendar")
            } currentValueLabel: {
                Text(total == 0 ? "–" : "\(remaining.count)").font(.system(.title3, design: .rounded).weight(.semibold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel(total == 0 ? "No events today" : "\(remaining.count) of \(total) events left today")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(total == 0 ? "Nothing today" : "\(remaining.count) of \(total) left").font(.headline).widgetAccentable()
                if let n = next {
                    Text(n.title).font(.caption).lineLimit(1)
                    if !reduced { Text(o.window(n)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
                } else { Text("You're done for today").font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            if total == 0 { Text("No events today") }
            else if let n = next { Text("\(remaining.count) left · next \(o.time(n.start))") }
            else { Text("Done for today") }
        #if os(watchOS)
        case .accessoryCorner:
            Text(remaining.isEmpty ? "–" : "\(remaining.count)").font(.system(.title3, design: .rounded).weight(.semibold)).widgetAccentable()
                .widgetLabel { Text(next.map { "\($0.title) · \(o.time($0.start))" } ?? "Done for today") }
        #endif
        default: EmptyView()
        }
    }
}
#endif
