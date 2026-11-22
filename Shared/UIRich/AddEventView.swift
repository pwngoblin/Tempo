import SwiftUI
import CalendarCore

/// The Add surface, modelled on Apple Calendar's New Event sheet: a grouped form (title, place, all-day,
/// start/end, calendar) whose first row is a quick-entry field that fills the form from a typed phrase.
struct AddEventView: View {
    var onDone: () -> Void

    var body: some View {
        let start = Self.nextHour()
        let end = start.addingTimeInterval(Double(PrefsStore.shared.values.defaultDurationMinutes) * 60)
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onDone).keyboardShortcut(.cancelAction)
                Spacer()
                Text("New Event").font(.headline)
                Spacer()
                Button("Cancel") {}.hidden()   // balances the header
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider()
            EventEditorView(target: .new(start: start, end: end), embedded: true, onClose: onDone, quickEntry: true)
                .frame(height: 400)
        }
        #else
        EventEditorView(target: .new(start: start, end: end), onClose: onDone, quickEntry: true)
        #endif
    }

    static func nextHour(_ now: Date = .now) -> Date {
        Calendar.tempo.dateInterval(of: .hour, for: now)?.end ?? now
    }
}
