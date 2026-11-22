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

    private var calendarInfo: CalendarInfo? {
        guard let parsed, !asReminder else { return nil }
        return manager.resolveCalendar(hint: parsed.calendarHint).map(CalendarInfo.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            #if os(watchOS)
            TextField(asReminder ? "Call mum tomorrow 5pm" : "Gym tomorrow 6pm", text: $text)
                .focused($focused)
                .onSubmit(commit)
            if let parsed {
                VStack(alignment: .leading, spacing: 2) {
                    Text(parsed.title).font(.headline).lineLimit(2)
                    Text(parsed.summary).font(.footnote).foregroundStyle(.secondary)
                }
                Button(action: commit) { Label("Send to iPhone", systemImage: "arrow.up.circle.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
            }
            #else
            HStack(spacing: 10) {
                Image(systemName: asReminder ? "checklist" : "calendar.badge.plus")
                    .font(.title2).foregroundStyle(.tint).symbolRenderingMode(.hierarchical)
                TextField(asReminder ? "Call mum tomorrow 5pm" : "Gym tomorrow 6pm", text: $text)
                    .focused($focused)
                    .onSubmit(commit)
                    .textFieldStyle(.plain)
                    .font(.title2)
                if !text.isEmpty {
                    Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain).accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if allowReminders {
                Picker("Type", selection: $asReminder) { Text("Event").tag(false); Text("Reminder").tag(true) }
                    .pickerStyle(.segmented).labelsHidden()
            }

            if let parsed {
                PreviewCard(parsed: parsed, calendar: calendarInfo, isReminder: asReminder)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                HStack {
                    Text("Return to add").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button(action: commit) { Label(asReminder ? "Add reminder" : "Add event", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text.isEmpty ? "Type it the way you'd say it" : "Add a time or day, e.g. “6pm” or “tomorrow”")
                        .font(.footnote).foregroundStyle(.secondary)
                    FlowChips(items: ["Lunch tomorrow 12:30-13:30 #Work", "Sync Fri 10am 45m @Zoom", "Gym 6pm"]) { text = $0 }
                }
            }
            #endif
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .animation(.snappy(duration: 0.2), value: parsed?.title)
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

#if !os(watchOS)
/// Big, readable summary of what will be created: title, when, where, and which calendar.
struct PreviewCard: View {
    let parsed: ParsedEvent
    let calendar: CalendarInfo?
    var isReminder = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(calendar.map { Color($0.color) } ?? Color.accentColor).frame(width: 5)
            VStack(alignment: .leading, spacing: 8) {
                Text(parsed.title).font(.headline).lineLimit(2)
                HStack(spacing: 6) {
                    chip(parsed.summary, "clock")
                    if let l = parsed.location { chip(l, "mappin") }
                    if let calendar { chip(calendar.title, "circle.fill", tint: Color(calendar.color)) }
                }
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(parsed.title), \(parsed.summary)")
    }

    private func chip(_ text: String, _ icon: String, tint: Color? = nil) -> some View {
        Label(text, systemImage: icon).labelStyle(.titleAndIcon).font(.caption).lineLimit(1)
            .foregroundStyle(tint ?? .secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.background.opacity(0.7), in: Capsule())
    }
}

/// Tappable example phrases (fill the field; never create anything).
struct FlowChips: View {
    let items: [String]
    let pick: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { t in
                Button { pick(t) } label: {
                    Text(t).font(.callout).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                }.buttonStyle(.plain)
            }
        }
    }
}
#endif
