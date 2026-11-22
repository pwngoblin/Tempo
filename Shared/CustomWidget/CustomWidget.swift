import WidgetKit
import SwiftUI
import AppIntents
import CalendarCore
import Widgetry

// The widget picker types must live in the extension target (App Intents are only discovered there).

struct CustomSpecEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Custom widget"
    static let defaultQuery = CustomSpecQuery()
    var id: UUID
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct CustomSpecQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [CustomSpecEntity] {
        TempoSpecStore.shared.load().filter { identifiers.contains($0.id) }.map { CustomSpecEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [CustomSpecEntity] {
        TempoSpecStore.shared.load().map { CustomSpecEntity(id: $0.id, name: $0.name) }
    }
}

struct PickCustomWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Custom widget"
    static let description = IntentDescription("Choose one of the widgets you designed in Tempo → Settings → Widgets.")
    @Parameter(title: "Widget") var widget: CustomSpecEntity?
    init() {}
}

struct CustomProvider: AppIntentTimelineProvider {
    typealias Intent = PickCustomWidgetIntent

    func placeholder(in context: Context) -> SpecEntry {
        SpecTimeline.preview(spec: SpecTemplates.countdown, sample: SpecTemplates.sample())
    }

    func snapshot(for configuration: PickCustomWidgetIntent, in context: Context) async -> SpecEntry {
        if context.isPreview { return placeholder(in: context) }
        let now = Date()
        let spec = Self.spec(configuration)
        return SpecEntry(date: now, spec: spec, context: Self.source(now: now).context(at: now))
    }

    func timeline(for configuration: PickCustomWidgetIntent, in context: Context) async -> Timeline<SpecEntry> {
        PrefsSnapshot.reload()
        return SpecTimeline.timeline(spec: Self.spec(configuration), source: Self.source(now: Date()))
    }

    private static func spec(_ i: PickCustomWidgetIntent) -> WidgetSpec? {
        i.widget.flatMap { TempoSpecStore.shared.spec(id: $0.id) }
    }

    /// Reads the active Calendar Set for the next week through `EventReader` (read-only).
    private static func source(now: Date) -> TempoCustomData {
        let store = CalendarSetStore()
        let e = TempoProvider.read(set: store.active, sets: store.sets, now: now, daysAhead: 7)
        return TempoCustomData(events: e.events, access: e.access)
    }
}

struct CustomWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TempoCustom", intent: PickCustomWidgetIntent.self, provider: CustomProvider()) { entry in
            SpecWidgetView(entry: entry)
                .widgetURL(DeepLink.today.url)
                .containerBackground(for: .widget) {
                    ZStack {
                        Rectangle().fill(.fill.tertiary)
                        if let tint = entry.spec?.background { tint.swiftUI.opacity(0.18) }
                    }
                }
        }
        .configurationDisplayName("Custom")
        .description("A widget you designed yourself in Tempo → Settings → Widgets.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
