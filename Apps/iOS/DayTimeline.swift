import SwiftUI
import CalendarCore

/// Single-day hour grid (Apple Calendar "Day" style): all-day strip, event blocks side by side, now line.
struct DayTimeline: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    let day: Date
    @ScaledMetric(relativeTo: .body) private var baseHourHeight: CGFloat = 56
    private var hourHeight: CGFloat { baseHourHeight * PrefsStore.shared.values.hourHeightScale }
    private let gutter: CGFloat = 52
    private let cal = Calendar.tempo

    var body: some View {
        let start = cal.startOfDay(for: day)
        let all = Agenda.events(manager.events(from: start, to: cal.date(byAdding: .day, value: 1, to: start)!), on: day)
        let allDay = all.filter(\.isAllDay)
        let placed = Agenda.layout(all)
        let firstHour = placed.map { cal.component(.hour, from: max($0.event.start, start)) }.min()
        let anchor = cal.isDateInToday(day) ? max(cal.component(.hour, from: .now) - 1, 0) : max((firstHour ?? PrefsStore.shared.values.scrollToHour) - 1, 0)

        VStack(spacing: 0) {
            if !allDay.isEmpty {
                VStack(spacing: 4) {
                    ForEach(allDay) { e in
                        Button { nav.detail = e } label: {
                            HStack { Text(e.title).font(.subheadline.weight(.medium)); Spacer(); Text("all-day").font(.caption).foregroundStyle(.secondary) }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color(e.color).opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal).padding(.vertical, 6)
                Divider()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { h in
                            HStack(alignment: .top, spacing: 6) {
                                Text(h == 0 ? "" : cal.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.hourText)
                                    .font(.caption2).foregroundStyle(.secondary).frame(width: gutter - 6, alignment: .trailing).offset(y: -6)
                                Rectangle().fill(.separator).frame(height: 0.5)
                            }.frame(height: hourHeight, alignment: .top).id(h)
                        }
                    }
                    .padding(.top, 8)
                    .overlay(alignment: .topLeading) {
                        GeometryReader { geo in
                            let width = geo.size.width - gutter - 8
                            ZStack(alignment: .topLeading) {
                                ForEach(placed) { p in block(p, start: start, width: width) }
                                if cal.isDateInToday(day) { nowLine(width: width) }
                            }
                            .offset(x: gutter, y: 8)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(anchor, anchor: .top) }
                .onChange(of: day) { _, _ in proxy.scrollTo(anchor, anchor: .top) }
            }
        }
        .gesture(DragGesture(minimumDistance: 40).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 2 else { return }
            withAnimation(.snappy) { nav.date = cal.date(byAdding: .day, value: v.translation.width < 0 ? 1 : -1, to: nav.date) ?? nav.date }
        })
    }

    private func block(_ p: Agenda.Placed, start: Date, width: CGFloat) -> some View {
        let e = p.event
        let s = max(e.start, start), t = min(e.end, cal.date(byAdding: .day, value: 1, to: start)!)
        let y = s.timeIntervalSince(start) / 3600 * hourHeight
        let h = max(t.timeIntervalSince(s) / 3600 * hourHeight - 1, 24)
        let w = width / CGFloat(p.columns)
        return Button { nav.detail = e } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(e.title).font(.caption.weight(.semibold)).lineLimit(h > 44 ? 2 : 1)
                if h > 40 { Text(e.start.timeText).font(.caption2).opacity(0.7) }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .frame(width: max(w - 2, 4), height: h, alignment: .topLeading)
            .eventBlock(Color(e.color), style: PrefsStore.shared.values.blockStyle)
        }
        .buttonStyle(.plain)
        .offset(x: w * CGFloat(p.column), y: y)
        .accessibilityLabel("\(e.title), \(e.timeRangeText)")
    }

    private func nowLine(width: CGFloat) -> some View {
        TimelineView(.everyMinute) { ctx in
            let c = cal.dateComponents([.hour, .minute], from: ctx.date)
            let y = (CGFloat(c.hour ?? 0) + CGFloat(c.minute ?? 0) / 60) * hourHeight
            HStack(spacing: 0) {
                Circle().fill(.red).frame(width: 8, height: 8).offset(x: -4)
                Rectangle().fill(.red).frame(width: width, height: 1)
            }.offset(y: y - 4).accessibilityHidden(true)
        }
    }
}
