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

    private var existing: EventItem? { if case .edit(let e) = target { e } else { nil } }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Location", text: $location)
                Toggle("All-day", isOn: $allDay)
                DatePicker("Starts", selection: $start, displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                DatePicker("Ends", selection: $end, in: start..., displayedComponents: allDay ? .date : [.date, .hourAndMinute])
                Picker("Calendar", selection: $calendarID) {
                    ForEach(manager.writableCalendars) { c in Label { Text(c.title) } icon: { Image(systemName: "circle.fill").foregroundStyle(Color(c.color)) }.tag(c.id) }
                }
                if let link = existing?.meetingLink { JoinButton(link: link, prominent: true) }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                if existing != nil {
                    Button("Delete Event", role: .destructive) { if existing!.hasRecurrence { askDelete = true } else { delete(.thisEvent) } }
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle(existing == nil ? "New Event" : "Edit Event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if existing?.hasRecurrence == true { askSpan = true } else { save(.thisEvent) } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || calendarID.isEmpty)
                        .keyboardShortcut(.defaultAction)
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
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 360)
        #endif
        .onAppear(perform: load)
    }

    private func load() {
        switch target {
        case .new(let s, let e):
            start = s; end = e; calendarID = manager.resolveCalendar(hint: nil)?.calendarIdentifier ?? manager.writableCalendars.first?.id ?? ""
        case .edit(let i):
            title = i.title; location = i.location ?? ""; start = i.start; end = i.end; allDay = i.isAllDay; calendarID = i.calendarID
        }
    }

    private func save(_ span: RecurrenceSpan) {
        do {
            let loc = location.trimmingCharacters(in: .whitespaces)
            if let e = existing {
                try manager.update(e, title: title, start: start, end: max(end, start), isAllDay: allDay, location: .some(loc.isEmpty ? nil : loc), calendarID: calendarID, span: span)
            } else if let cal = manager.store.calendar(withIdentifier: calendarID) {
                try manager.create(title: title, start: start, end: max(end, start), isAllDay: allDay, location: loc.isEmpty ? nil : loc, calendar: cal)
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func delete(_ span: RecurrenceSpan) {
        do { try manager.delete(existing!, span: span); dismiss() } catch { self.error = error.localizedDescription }
    }
}
