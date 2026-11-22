import AppIntents
import CalendarCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// A Calendar Set as an App Intents entity (widget configuration + Shortcuts).
struct CalendarSetEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar Set"
    static let defaultQuery = CalendarSetQuery()
    var id: UUID
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(_ set: CalendarSet) { id = set.id; name = set.name }
}

struct CalendarSetQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CalendarSetEntity] {
        CalendarSetStore().sets.filter { identifiers.contains($0.id) }.map(CalendarSetEntity.init)
    }
    func suggestedEntities() async throws -> [CalendarSetEntity] { CalendarSetStore().sets.map(CalendarSetEntity.init) }
    func defaultResult() async -> CalendarSetEntity? { CalendarSetEntity(.all) }
}

/// Button action inside widgets: make a set the active filter.
struct SetActiveSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Switch Calendar Set"
    static let isDiscoverable = false
    @Parameter(title: "Set ID") var setID: String
    init() {}
    init(setID: UUID) { self.setID = setID.uuidString }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: setID) { CalendarSetStore().activeID = id }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

/// Button action inside widgets: step to the next set.
struct CycleSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Calendar Set"
    static let isDiscoverable = false
    init() {}
    func perform() async throws -> some IntentResult {
        CalendarSetStore().cycle()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}
