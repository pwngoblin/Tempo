import SwiftUI
import CalendarCore

struct MonthView: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav
    private let cal = Calendar.tempo

    var body: some View {
        let cells = cal.monthGrid(for: nav.date)
        let rows = cells.count / 7
        let days = cells.compactMap { $0 }
        let byDay = Agenda.byDay(manager.events(from: days.first ?? nav.date, to: cal.date(byAdding: .day, value: 1, to: days.last ?? nav.date)!), calendar: cal)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(cal.orderedShortWeekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
            }
            Divider()
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<rows, id: \.self) { r in
                    GridRow {
                        ForEach(0..<7, id: \.self) { c in
                            if let d = cells[r * 7 + c] { cell(d, byDay[cal.startOfDay(for: d)] ?? []) } else { Color.clear }
                        }
                    }
                }
            }
        }
    }

    private func cell(_ d: Date, _ events: [EventItem]) -> some View {
        let isToday = cal.isDateInToday(d), isSel = cal.isDate(d, inSameDayAs: nav.date)
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(cal.component(.day, from: d))").font(.callout.monospacedDigit().weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.white : .primary)
                .frame(minWidth: 22, minHeight: 22).background(isToday ? Color.red : .clear, in: Circle())
            ForEach(events.prefix(3)) { e in
                Text(e.title).font(.caption2).lineLimit(1).padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(e.color).opacity(0.28), in: RoundedRectangle(cornerRadius: 3))
            }
            if events.count > 3 { Text("+\(events.count - 3) more").font(.caption2).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isSel ? Color.accentColor.opacity(0.12) : .clear)
        .overlay(alignment: .topLeading) { Rectangle().fill(.separator).frame(height: 0.5) }
        .overlay(alignment: .leading) { Rectangle().fill(.separator).frame(width: 0.5) }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { nav.date = d; nav.mode = .day }
        .onTapGesture { nav.date = d }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(d.formatted(date: .complete, time: .omitted) + ", \(events.count) events")
    }
}
