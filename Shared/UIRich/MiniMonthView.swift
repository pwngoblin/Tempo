import SwiftUI
import CalendarCore

/// Month grid with colour-coded event dots. Fetches its own events for the visible grid.
struct MiniMonthView: View {
    @Environment(EventStoreManager.self) private var manager
    @Binding var selected: Date
    var large = false
    @State private var shown: Date = .now
    private let cal = Calendar.tempo
    @ScaledMetric(relativeTo: .body) private var circle: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var cellMin: CGFloat = 44

    var body: some View {
        let weekNumbers = PrefsStore.shared.values.showWeekNumbers
        let cells = cal.monthGrid(for: shown)
        let days = cells.compactMap { $0 }
        let byDay: [Date: [EventItem]] = {
            guard let first = days.first, let last = days.last else { return [:] }
            return Agenda.byDay(manager.events(from: first, to: cal.date(byAdding: .day, value: 1, to: last)!), calendar: cal)
        }()

        VStack(spacing: large ? 8 : 4) {
            HStack {
                Text(shown, format: .dateTime.month(.wide).year()).font(large ? .title3.bold() : .subheadline.bold())
                Spacer()
                Button { move(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                Button { selected = .now; shown = .now } label: { Image(systemName: "circle.fill").font(.system(size: 6)) }.accessibilityLabel("Today")
                Button { move(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month")
            }.buttonStyle(.borderless)

            Grid(horizontalSpacing: 0, verticalSpacing: large ? 6 : 2) {
                GridRow {
                    if weekNumbers { Text("").frame(width: 20) }
                    ForEach(Array(cal.orderedShortWeekdaySymbols.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<(cells.count / 7), id: \.self) { row in
                    GridRow {
                        if weekNumbers {
                            let any = (0..<7).compactMap { cells[row * 7 + $0] }.first
                            Text(any.map { "\(cal.component(.weekOfYear, from: $0))" } ?? "").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 20)
                        }
                        ForEach(0..<7, id: \.self) { col in
                            if let d = cells[row * 7 + col] { dayCell(d, events: byDay[cal.startOfDay(for: d)] ?? []) }
                            else { Color.clear.frame(height: large ? cellMin : 26) }
                        }
                    }
                }
            }
        }
        .onAppear { shown = selected }
        .onChange(of: selected) { _, new in if !cal.isDate(new, equalTo: shown, toGranularity: .month) { shown = new } }
    }

    private func dayCell(_ d: Date, events: [EventItem]) -> some View {
        let isSel = cal.isDate(d, inSameDayAs: selected), isToday = cal.isDateInToday(d)
        var colors: [RGBA] = []
        for e in events where !colors.contains(e.color) && colors.count < 3 { colors.append(e.color) }
        return Button { selected = d } label: {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: d))")
                    .font(large ? .body : .caption).monospacedDigit()
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isToday ? Color.white : .primary)
                    .frame(width: large ? circle : 22, height: large ? circle : 22)
                    .background(isToday ? Color.red : .clear, in: Circle())
                HStack(spacing: 2) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, c in Circle().fill(Color(c)).frame(width: 4, height: 4) }
                }.frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: large ? cellMin : 26)
            .background(isSel ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(d.formatted(date: .complete, time: .omitted) + (events.isEmpty ? "" : ", \(events.count) events"))
    }

    private func move(_ by: Int) { shown = cal.date(byAdding: .month, value: by, to: shown) ?? shown }
}
