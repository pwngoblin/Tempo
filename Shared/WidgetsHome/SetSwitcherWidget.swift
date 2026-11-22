import WidgetKit
import SwiftUI
import AppIntents
import CalendarCore

/// Interactive: tap a chip to filter by that Calendar Set, or the arrow to cycle.
struct SetSwitcherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoSetSwitcher", intent: TempoWidgetIntent.self, provider: TempoProvider(followsActiveSetOnly: true)) { entry in
            SetSwitcherView(entry: entry).widgetURL(DeepLink.today.url).tempoBackground(entry.options)
        }
        .configurationDisplayName("Calendar Sets")
        .description("Switch between Calendar Sets right from the widget.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct SetSwitcherView: View {
    let entry: TempoEntry
    private var o: WidgetOptions { entry.options }

    var body: some View {
        if entry.access != .full { NoAccessView() }
        else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(entry.sets.prefix(4)) { s in
                        let on = s.id == entry.set.id
                        Button(intent: SetActiveSetIntent(setID: s.id)) {
                            Text(s.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(on ? o.tintColor : Color.primary.opacity(0.12), in: Capsule())
                                .foregroundStyle(on ? Color.white : .primary)
                                .widgetAccentable(on)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                    Spacer(minLength: 0)
                    Button(intent: CycleSetIntent()) { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11, weight: .semibold)).padding(4) }
                        .buttonStyle(.plain).accessibilityLabel("Next calendar set")
                }
                let end = Calendar.tempo.date(byAdding: .day, value: o.daysAhead, to: Calendar.tempo.startOfDay(for: entry.date)) ?? entry.date
                AgendaListView(events: entry.events.filter { $0.start < end }, now: entry.date, options: o)
            }
        }
    }
}
