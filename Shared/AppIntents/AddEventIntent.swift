import AppIntents
import CalendarCore

/// "Add event" for Siri / Shortcuts / the watch: free text goes through the same local parser.
struct AddEventIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Event"
    static let description = IntentDescription("Create a calendar event from a natural-language phrase, e.g. “Gym tomorrow 18:00-19:30 #Personal”.")

    @Parameter(title: "Event", requestValueDialog: "What's the event?") var text: String
    static var parameterSummary: some ParameterSummary { Summary("Add \(\.$text) to Tempo") }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        #if os(watchOS)
        guard let parsed = EventParser().parse(text) else { return .result(dialog: "I didn't catch an event.") }
        WatchLink.shared.sendAdd(text)
        return .result(dialog: "Sent to your iPhone: \(parsed.title), \(parsed.summary).")
        #else
        let manager = EventStoreManager(setStore: CalendarSetStore())
        if manager.eventAccess == .notDetermined { await manager.requestAccess() }
        guard let parsed = EventParser().parse(text) else { return .result(dialog: "I didn't catch an event.") }
        let item = try manager.create(parsed)
        return .result(dialog: "Added \(item.title), \(parsed.summary).")
        #endif
    }
}

struct TempoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddEventIntent(), phrases: ["Add an event in \(.applicationName)", "New \(.applicationName) event"],
                    shortTitle: "Add Event", systemImageName: "calendar.badge.plus")
    }
}
