import SwiftUI
import CalendarCore

/// Natural-language quick add with a live preview pill. Used by the Mac command bar and menu-bar
/// popover, the iOS sheet and the watch.
struct QuickAddView: View {
    @Environment(EventStoreManager.self) private var manager
    @State private var text = ""
    @State private var asReminder = false
    @State private var error: String?
    @State private var saved = 0
    @FocusState private var focused: Bool
    var autofocus = true
    var allowReminders = false
    var onDone: () -> Void = {}

    private var parsed: ParsedEvent? {
        EventParser(calendar: .tempo, defaultDuration: Double(PrefsStore.shared.values.defaultDurationMinutes) * 60).parse(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(asReminder ? "Call mum tomorrow 5pm" : "Gym tomorrow 18:00-19:30 #Personal", text: $text)
                .focused($focused)
                .onSubmit(commit)
                #if !os(watchOS)
                .textFieldStyle(.plain)
                .font(.title3)
                #endif
            #if !os(watchOS)
            if allowReminders {
                Picker("Type", selection: $asReminder) { Text("Event").tag(false); Text("Reminder").tag(true) }
                    .pickerStyle(.segmented).labelsHidden()
            }
            #endif
            #if !os(watchOS)
            if parsed == nil {
                Text("Try “Lunch tomorrow 12:30-13:30 #Work”, “Sync Fri 10am 45m @Zoom”, or “Gym 6pm”.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            #endif
            if let parsed { PreviewPill(parsed: parsed, calendar: asReminder ? nil : manager.resolveCalendar(hint: parsed.calendarHint).map(CalendarInfo.init)) }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .task { if autofocus { focused = true } }
        .tempoHaptic(.success, trigger: saved)
    }

    private func commit() {
        guard let p = parsed else { return }
        #if os(watchOS)
        // EventKit is read-only on the watch: hand the phrase to the paired iPhone.
        WatchLink.shared.sendAdd(text)
        text = ""; error = nil; saved += 1; onDone()
        return
        #else
        do {
            if asReminder { try manager.createReminder(title: p.title, due: (p.hasExplicitDate || p.hasExplicitTime) ? p.start : nil) }
            else { try manager.create(p) }
            text = ""; error = nil; saved += 1; onDone()
        } catch { self.error = error.localizedDescription }
        #endif
    }
}

struct PreviewPill: View {
    let parsed: ParsedEvent
    let calendar: CalendarInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(calendar.map { Color($0.color) } ?? .secondary).frame(width: 8, height: 8)
                Text(parsed.title).font(.caption.weight(.semibold)).lineLimit(1)
                if let calendar { Text(calendar.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
            HStack(spacing: 6) {
                Text(parsed.summary).font(.caption).monospacedDigit()
                if let l = parsed.location { Label(l, systemImage: "mappin").labelStyle(.titleAndIcon).font(.caption).lineLimit(1) }
            }.foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(parsed.title), \(parsed.summary)")
    }
}
