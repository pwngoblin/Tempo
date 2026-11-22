import SwiftUI
import CalendarCore

enum EditorTarget: Identifiable, Hashable {
    case new(start: Date, end: Date)
    case edit(EventItem)
    var id: String {
        switch self {
        case .new(let s, let e): "new-\(s.timeIntervalSince1970)-\(e.timeIntervalSince1970)"
        case .edit(let i): i.id
        }
    }
}

struct EventEditorView: View {
    let target: EditorTarget
    /// Embedded in the Add sheet / command bar: no own navigation bar, an inline Add button, and `onClose` instead of dismiss.
    var embedded = false
    var onClose: (() -> Void)? = nil
    /// New events only: a first row that fills the form from a typed phrase ("Gym tomorrow 6pm").
    var quickEntry = false
    @State private var quickText = ""
    @State private var asReminder = false
    @FocusState private var quickFocused: Bool
    @Environment(EventStoreManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var location = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var allDay = false
    @State private var calendarID = ""
    @State private var askSpan = false
    @State private var askDelete = false
    @State private var error: String?

    private func close() { if let onClose { onClose() } else { dismiss() } }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && (asReminder || !calendarID.isEmpty) }

    private var existing: EventItem? { if case .edit(let e) = target { e } else { nil } }

    var body: some View {
        Group {
            if embedded { form }
            else {
                NavigationStack {
                    form
                        .navigationTitle(existing == nil ? "New Event" : "Edit Event")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { close() } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button(existing == nil ? (asReminder ? "Add" : "Add") : "Save") { if existing?.hasRecurrence == true { askSpan = true } else { save(.thisEvent) } }
                                    .disabled(!canSave).keyboardShortcut(.defaultAction)
                            }
                        }
                }
            }
        }
        .confirmationDialog("This is a repeating event", isPresented: $askSpan) {
            Button("Save for This Event Only") { save(.thisEvent) }
            Button("Save for Future Events") { save(.futureEvents) }
        }
        .confirmationDialog("This is a repeating event", isPresented: $askDelete) {
            Button("Delete This Event Only", role: .destructive) { delete(.thisEvent) }
            Button("Delete All Future Events", role: .destructive) { delete(.futureEvents) }
        }
        #if os(macOS)
        .frame(minWidth: embedded ? 0 : 400, minHeight: embedded ? 0 : 360)
        #endif
        .onAppear(perform: load)
    }

    private var form: some View {
        Form {
            if quickEntry, existing == nil {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(.tint)
                        TextField("Type it: Gym tomorrow 6pm", text: $quickText)
                            .focused($quickFocused)
                            .onChange(of: quickText) { _, t in applyQuick(t) }
                    }
                    #if !os(watchOS)
                    Picker("Add as", selection: $asReminder) { Text("Event").tag(false); Text("Reminder").tag(true) }
                        .pickerStyle(.segmented)
                    #endif
                } footer: { Text("Fills in the fields below. You can still edit them.") }
            }
            TextField("Title", text: $title)
            if asReminder {
                DatePicker("Due", selection: $start, displayedComponents: [.date, .hourAndMinute])
            } else {
                TextField("Location", text: $location)
                Toggle("All-day", isOn: $allDay)
                DatePicker("Starts", selection: $start, displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                DatePicker("Ends", selection: $end, in: start..., displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                Picker("Calendar", selection: $calendarID) {
                    ForEach(manager.writableCalendars) { c in Label { Text(c.title) } icon: { Image(systemName: "circle.fill").foregroundStyle(Color(c.color)) }.tag(c.id) }
                }
            }
            if let link = existing?.meetingLink { JoinButton(link: link, prominent: true) }
            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            if embedded {
                HStack {
                    Spacer()
                    Button { save(.thisEvent) } label: { Label(asReminder ? "Add reminder" : "Add event", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(!canSave)
                        .keyboardShortcut(.defaultAction)
                }
            }
            if existing != nil {
                Button("Delete Event", role: .destructive) { if existing!.hasRecurrence { askDelete = true } else { delete(.thisEvent) } }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private func applyQuick(_ text: String) {
        let d = Double(PrefsStore.shared.values.defaultDurationMinutes) * 60
        guard let p = EventParser(calendar: .tempo, defaultDuration: d).parse(text) else { return }
        title = p.title; start = p.start; end = p.end; allDay = p.isAllDay
        location = p.location ?? location
        if let c = manager.resolveCalendar(hint: p.calendarHint)?.calendarIdentifier { calendarID = c }
    }

    private func load() {
        if quickEntry { quickFocused = true }
        switch target {
        case .new(let s, let e):
            start = s; end = e; calendarID = manager.resolveCalendar(hint: nil)?.calendarIdentifier ?? manager.writableCalendars.first?.id ?? ""
        case .edit(let i):
            title = i.title; location = i.location ?? ""; start = i.start; end = i.end; allDay = i.isAllDay; calendarID = i.calendarID
        }
    }

    private func save(_ span: RecurrenceSpan) {
        do {
            if asReminder, existing == nil { try manager.createReminder(title: title, due: start); close(); return }
            let loc = location.trimmingCharacters(in: .whitespaces)
            if let e = existing {
                try manager.update(e, title: title, start: start, end: max(end, start), isAllDay: allDay, location: .some(loc.isEmpty ? nil : loc), calendarID: calendarID, span: span)
            } else if let cal = manager.store.calendar(withIdentifier: calendarID) {
                try manager.create(title: title, start: start, end: max(end, start), isAllDay: allDay, location: loc.isEmpty ? nil : loc, calendar: cal)
            }
            close()
        } catch { self.error = error.localizedDescription }
    }

    private func delete(_ span: RecurrenceSpan) {
        do { try manager.delete(existing!, span: span); close() } catch { self.error = error.localizedDescription }
    }
}
