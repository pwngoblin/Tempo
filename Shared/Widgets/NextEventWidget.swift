import WidgetKit
import SwiftUI
import CalendarCore

/// Current / next event with live countdown, free-time status, and Lock Screen / watchOS complications.
struct NextEventWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoNextEvent", intent: TempoWidgetIntent.self, provider: TempoProvider()) { entry in
            NextEventView(entry: entry)
                .widgetURL((entry.current ?? entry.next).map { DeepLink.event($0.eventID).url } ?? DeepLink.today.url)
        }
        .configurationDisplayName("Next Event")
        .description("What's happening now, what's next, and how long you're free.")
        .supportedFamilies(Self.families)
    }

    static var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline]
        #elseif os(macOS)
        [.systemSmall, .systemMedium]
        #else
        [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

struct NextEventView: View {
    let entry: TempoEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.isLuminanceReduced) private var reduced
    private var o: WidgetOptions { entry.options }

    var body: some View {
        content.containerBackground(for: .widget) {
            switch family {
            case .accessoryCircular: AccessoryWidgetBackground()
            #if !os(watchOS)
            case .systemSmall, .systemMedium: Rectangle().fill(.clear).tempoBackgroundFill(o)
            #endif
            default: Color.clear
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        #if os(watchOS)
        case .accessoryCorner: corner
        #else
        case .systemMedium: medium.padding(.vertical, 2)
        default: small
        #endif
        }
    }

    // MARK: Lock Screen / complications
    private var circular: some View {
        Group {
            if entry.access != .full {
                Image(systemName: "calendar.badge.exclamationmark")
            } else if let cur = entry.current {
                ProgressView(timerInterval: cur.start...max(cur.end, cur.start.addingTimeInterval(1)), countsDown: false) {
                    Image(systemName: "calendar")
                } currentValueLabel: {
                    CountdownText(date: cur.end, style: .timer).font(.system(size: 11)).minimumScaleFactor(0.5)
                }
                .progressViewStyle(.circular)
            } else if let next = entry.next, next.start.timeIntervalSince(entry.date) < 3600, o.countdown != .off {
                ProgressView(timerInterval: entry.date...next.start, countsDown: true) {
                    Image(systemName: "calendar")
                } currentValueLabel: {
                    Text(next.start, style: .timer).font(.system(size: 11).monospacedDigit()).minimumScaleFactor(0.5)
                }
                .progressViewStyle(.circular)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: entry.next == nil ? "checkmark" : "calendar").font(.system(size: 12)).widgetAccentable()
                    Text(entry.next.map { o.time($0.start) } ?? "Free").font(.system(size: 12, weight: .semibold)).minimumScaleFactor(0.6)
                }
            }
        }
        .accessibilityLabel(accessibilitySummary)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if entry.access != .full {
                Text("Open Tempo to allow access").font(.caption2)
            } else if let focus = entry.current ?? entry.next {
                Text(entry.current != nil ? "NOW" : "NEXT").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                Text(focus.title).font(.headline).lineLimit(1).widgetAccentable()
                Text(o.window(focus)).font(.caption.monospacedDigit()).lineLimit(1)
                if !reduced, o.showFollowing, let f = entry.following {
                    Text("Then \(f.title) · \(o.time(f.start))").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Text("Free all day").font(.headline).widgetAccentable()
                Text("Nothing scheduled").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var inline: some View {
        Group {
            if entry.access != .full { Text("Tempo: allow access") }
            else {
                switch o.inlineStyle {
                case .smart: smartInline
                case .nextWithTime:
                    if let n = entry.next { Text("Next: \(n.title) · \(o.time(n.start))") } else { Text("No more events") }
                case .countdown:
                    if let n = entry.next { Text("\(n.title) · ") + Text(n.start, style: .relative) } else { Text("No more events") }
                case .freeBusy:
                    if let busy = Agenda.busyUntil(entry.events, at: entry.date) { Text("Busy until \(o.time(busy))") }
                    else if let free = Agenda.freeUntil(entry.events, at: entry.date) { Text("Free until \(o.time(free))") }
                    else { Text("Free") }
                }
            }
        }
    }

    @ViewBuilder private var smartInline: some View {
        if let cur = entry.current { Text("Now: \(cur.title) until \(o.time(cur.end))") }
        else if let next = entry.next {
            // A far-off next event reads as free time; an imminent one as "Next:".
            if next.start.timeIntervalSince(entry.date) > 90 * 60 { Text("Free until \(o.time(next.start))") }
            else { Text("Next: \(next.title) · \(o.time(next.start))") }
        } else { Text("No more events today") }
    }

    #if os(watchOS)
    private var corner: some View {
        let focus = entry.current ?? entry.next
        return Image(systemName: entry.current != nil ? "calendar.badge.clock" : "calendar")
            .widgetAccentable()
            .widgetLabel {
                if let focus { Text("\(focus.title) · \(o.time(entry.current != nil ? focus.end : focus.start))") }
                else { Text("Free") }
            }
    }
    #endif

    private var accessibilitySummary: String {
        if let c = entry.current { return "Now: \(c.title), ends \(o.time(c.end))" }
        if let n = entry.next { return "Next: \(n.title) at \(o.time(n.start))" }
        return "No more events"
    }

    // MARK: Home screen / desktop
    #if !os(watchOS)
    private var small: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.access != .full { NoAccessView() }
            else if let focus = entry.current ?? entry.next {
                let isNow = entry.current != nil
                HStack(spacing: 4) {
                    status(isNow ? "NOW" : "NEXT", color: focus.color)
                    Spacer(minLength: 0)
                    if o.showMeetingIcon, let link = focus.meetingLink {
                        Image(systemName: link.provider.symbol).font(.caption2).foregroundStyle(.secondary).widgetAccentable()
                    }
                }
                Text(focus.title).font(.headline).lineLimit(2)
                if o.showLocation, let place = focus.location, !place.isEmpty, focus.meetingLink == nil || !isNow {
                    Label(place, systemImage: "mappin").labelStyle(.titleAndIcon).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                if o.showCalendarName, !focus.calendarTitle.isEmpty {
                    Label(focus.calendarTitle, systemImage: "circle.fill").labelStyle(.titleAndIcon).font(.caption2)
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if isNow, !reduced {
                    ProgressView(timerInterval: focus.start...max(focus.end, focus.start.addingTimeInterval(1)), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                        .progressViewStyle(.linear).tint(o.color(focus.color))
                }
                if o.countdown != .off {
                    Text(isNow ? "ends in" : "starts in").font(.caption2).foregroundStyle(.secondary)
                    CountdownText(date: isNow ? focus.end : focus.start, style: o.countdown).font(.title3.weight(.semibold))
                }
                Text(o.window(focus) + (focus.isAllDay ? "" : " · \(durationText(focus))")).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                if o.showFollowing, let f = entry.following {
                    Text("Then \(o.time(f.start)) \(f.title)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(.green).widgetAccentable()
                Text("Free").font(.headline)
                Text("No more events").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func durationText(_ e: EventItem) -> String {
        let m = Int(e.end.timeIntervalSince(e.start) / 60)
        return m >= 60 ? (m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m") : "\(m)m"
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            small.frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                if let free = Agenda.freeUntil(entry.events, at: entry.date) {
                    Label("Free until \(o.time(free))", systemImage: "checkmark.circle").font(.caption.weight(.semibold)).foregroundStyle(.green)
                } else if let busy = Agenda.busyUntil(entry.events, at: entry.date) {
                    Label("Busy until \(o.time(busy))", systemImage: "clock").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
                if o.showFollowing {
                    AgendaListView(events: entry.events.filter { $0.id != (entry.current ?? entry.next)?.id }, now: entry.date, options: o)
                }
            }.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
    }

    private func status(_ label: String, color: RGBA) -> some View {
        HStack(spacing: 4) {
            Circle().fill(o.color(color)).frame(width: 6, height: 6).widgetAccentable()
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
        }
    }
    #endif
}

extension View {
    /// Fills a shape with the chosen background (used inside `containerBackground`).
    func tempoBackgroundFill(_ o: WidgetOptions) -> some View {
        overlay {
            switch o.background {
            case .system: Rectangle().fill(.fill.tertiary)
            case .tinted: o.tintColor.opacity(0.18)
            case .clear: Color.clear
            }
        }
    }
}
