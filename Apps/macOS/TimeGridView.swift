import SwiftUI
import CalendarCore

/// Day / Week time-blocking grid: current-time indicator, drag on empty space to create,
/// drag an event's bottom edge to resize (snaps to 15 min), click to edit.
struct TimeGridView: View {
    @Environment(EventStoreManager.self) private var manager
    let days: [Date]
    private var hourHeight: CGFloat { 56 * PrefsStore.shared.values.hourHeightScale }
    private let gutter: CGFloat = 52
    private let cal = Calendar.tempo

    var body: some View {
        let first = cal.startOfDay(for: days.first!)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: days.last!))!
        let events = manager.events(from: first, to: end)

        VStack(spacing: 0) {
            header(events)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(hourLabel(h)).font(.caption2).foregroundStyle(.secondary)
                                    .frame(width: gutter - 6, height: hourHeight, alignment: .topTrailing).offset(y: -6).id(h)
                            }
                        }.frame(width: gutter)
                        ForEach(days, id: \.self) { day in
                            DayColumn(day: day, events: Agenda.events(events, on: day).filter { !$0.isAllDay }, hourHeight: hourHeight)
                        }
                    }
                    .padding(.top, 8)
                }
                .onAppear {
                    let today = days.contains { cal.isDateInToday($0) }
                    proxy.scrollTo(max(today ? cal.component(.hour, from: .now) - 2 : PrefsStore.shared.values.scrollToHour, 0), anchor: .top)
                }
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        h == 0 ? "" : cal.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.hourText
    }

    private func header(_ events: [EventItem]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear.frame(width: gutter, height: 1)
            ForEach(days, id: \.self) { day in
                let isToday = cal.isDateInToday(day)
                VStack(spacing: 3) {
                    Text(day, format: .dateTime.weekday(.abbreviated)).font(.caption).foregroundStyle(.secondary)
                    Text("\(cal.component(.day, from: day))").font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(isToday ? Color.white : .primary)
                        .frame(minWidth: 30, minHeight: 30).background(isToday ? Color.red : .clear, in: Circle())
                    ForEach(PrefsStore.shared.values.showAllDayStrip ? Agenda.events(events, on: day).filter(\.isAllDay) : []) { e in
                        Text(e.title).font(.caption2).lineLimit(1).padding(.horizontal, 4)
                            .frame(maxWidth: .infinity).background(Color(e.color).opacity(0.3), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DayColumn: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    let day: Date
    let events: [EventItem]
    let hourHeight: CGFloat
    @State private var dragFrom: CGFloat?
    @State private var dragTo: CGFloat = 0
    private let cal = Calendar.tempo

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { _ in Color.clear.frame(height: hourHeight).overlay(alignment: .top) { Divider() } }
                }
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 6).onChanged { v in dragFrom = v.startLocation.y; dragTo = v.location.y }
                        .onEnded { v in finishDrag(v.startLocation.y, v.location.y) })
                    .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { v in finishDrag(v.location.y, v.location.y + hourHeight) })

                ForEach(Agenda.layout(events)) { p in
                    EventBlock(placed: p, day: day, width: geo.size.width, hourHeight: hourHeight)
                }
                if let from = dragFrom {
                    let a = min(from, dragTo), b = max(from, dragTo)
                    RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.3))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.accentColor))
                        .frame(width: geo.size.width - 2, height: max(b - a, 4)).offset(y: a).allowsHitTesting(false)
                }
                if cal.isDateInToday(day) { NowIndicator(hourHeight: hourHeight) }
            }
        }
        .frame(maxWidth: .infinity).frame(height: hourHeight * 24)
        .overlay(alignment: .leading) { Divider() }
    }

    private func snapped(_ y: CGFloat) -> Date {
        let minutes = min(max(Int((y / hourHeight * 60 / 15).rounded()) * 15, 0), 24 * 60 - 15)
        return cal.date(byAdding: .minute, value: minutes, to: cal.startOfDay(for: day))!
    }

    private func finishDrag(_ y0: CGFloat, _ y1: CGFloat) {
        defer { dragFrom = nil }
        let (a, b) = (min(y0, y1), max(y0, y1))
        var s = snapped(a), e = snapped(b)
        if e.timeIntervalSince(s) < 15 * 60 { e = s.addingTimeInterval(30 * 60) }
        if abs(y1 - y0) < 6 { s = snapped(y0); e = s.addingTimeInterval(Double(PrefsStore.shared.values.defaultDurationMinutes) * 60) }
        nav.editor = .new(start: s, end: e)
    }
}

private struct EventBlock: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    let placed: Agenda.Placed
    let day: Date
    let width: CGFloat
    let hourHeight: CGFloat
    @State private var resize: CGFloat = 0
    @State private var showDetail = false
    private let cal = Calendar.tempo

    var body: some View {
        let e = placed.event
        let dayStart = cal.startOfDay(for: day)
        let s = max(e.start, dayStart)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let t = min(e.end, endOfDay)
        let y = s.timeIntervalSince(dayStart) / 3600 * hourHeight
        let h = max(t.timeIntervalSince(s) / 3600 * hourHeight + resize, 20)
        let w = width / CGFloat(placed.columns)

        VStack(alignment: .leading, spacing: 1) {
            Text(e.title).font(.caption.weight(.semibold)).lineLimit(h > 34 ? 2 : 1)
            if h > 34 { Text(e.start.timeText).font(.caption2).opacity(0.7) }
            if h > 50, let link = e.meetingLink { Label(link.provider.name, systemImage: link.provider.symbol).font(.caption2).opacity(0.7) }
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .frame(width: max(w - 2, 4), height: h, alignment: .topLeading)
        .eventBlock(Color(e.color), style: PrefsStore.shared.values.blockStyle, corner: 5)
        .overlay(alignment: .bottom) {
            if e.canModify {
                Color.clear.frame(height: 8).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 2).onChanged { resize = $0.translation.height }.onEnded { v in commitResize(v.translation.height) })
                    .onHover { inside in if inside { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .popover(isPresented: $showDetail, arrowEdge: .trailing) { EventDetailView(event: e, onEdit: { showDetail = false; nav.editor = .edit(e) }) }
        .offset(x: w * CGFloat(placed.column) + 1, y: y)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(e.title), \(e.timeRangeText)")
    }

    private func commitResize(_ dy: CGFloat) {
        defer { resize = 0 }
        let e = placed.event
        let minutes = (Double(dy / hourHeight) * 60 / 15).rounded() * 15
        let newEnd = max(e.end.addingTimeInterval(minutes * 60), e.start.addingTimeInterval(15 * 60))
        guard newEnd != e.end else { return }
        do { try manager.update(e, end: newEnd, span: .thisEvent) } catch { manager.lastError = error.localizedDescription }
    }
}

private struct NowIndicator: View {
    let hourHeight: CGFloat
    var body: some View {
        TimelineView(.everyMinute) { ctx in
            let cal = Calendar.tempo
            let m = cal.dateComponents([.hour, .minute], from: ctx.date)
            let y = (CGFloat(m.hour ?? 0) + CGFloat(m.minute ?? 0) / 60) * hourHeight
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 8, height: 8).offset(x: -4)
                Rectangle().fill(.red).frame(height: 1)
            }
            .offset(y: y - 4).allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}
