import SwiftUI
import CalendarCore
import Widgetry

/// Settings → Widgets: the user's own widgets, with New / Edit / Duplicate / Delete. The editor opens in a sheet on
/// iPhone and in its own window on the Mac.
struct CustomWidgetsView: View {
    @Environment(EventStoreManager.self) private var manager
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @State private var specs: [WidgetSpec] = []
    @State private var editing: WidgetSpec?
    @State private var error: String?
    private var store: SpecStore { TempoSpecStore.shared }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Design your own widgets").font(.title2.weight(.semibold))
                    Text("Pick a template, restyle it in the editor, then add the **Custom** widget from the widget gallery and choose your design. Data comes from your active Calendar Set and never leaves your device.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }

                if !specs.isEmpty {
                    section("Your widgets") {
                        ForEach(specs) { spec in
                            card(spec, subtitle: "Tap to edit") { edit(spec) }
                                .contextMenu {
                                    Button("Edit", systemImage: "pencil") { edit(spec) }
                                    Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(spec) }
                                    Button("Delete", systemImage: "trash", role: .destructive) { delete(spec) }
                                }
                        }
                    }
                }

                section(specs.isEmpty ? "Start with a template" : "New from a template") {
                    ForEach(SpecTemplates.all) { t in card(t, subtitle: "Use this template") { create(from: t) } }
                }

                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Custom Widgets")
        .onAppear(perform: reload)
        #if !os(macOS)
        .sheet(item: $editing, onDismiss: reload) { spec in
            NavigationStack { CustomWidgetEditor(spec: spec, onClose: { editing = nil }) }
                .environment(manager)
        }
        #endif
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 16, alignment: .top)], alignment: .leading, spacing: 18, content: content)
        }
    }

    private func card(_ spec: WidgetSpec, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                SpecView(spec: spec, context: SpecTemplates.sample())
                    .padding(12).frame(width: 158, height: 158, alignment: .topLeading)
                    .background(SpecBackground(spec: spec))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .allowsHitTesting(false)
                Text(spec.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spec.name). \(subtitle)")
    }

    private func reload() { specs = store.load() }

    private func edit(_ spec: WidgetSpec) {
        #if os(macOS)
        openWindow(id: "widget-editor", value: spec.id)
        #else
        editing = spec
        #endif
    }

    private func create(from template: WidgetSpec) {
        var s = template; s.id = UUID()
        do { try store.upsert(s); error = nil; reload(); edit(s) } catch { self.error = "\(error)" }
    }

    private func duplicate(_ spec: WidgetSpec) {
        var s = spec; s.id = UUID(); s.name += " copy"
        do { try store.upsert(s); error = nil; reload() } catch { self.error = "\(error)" }
    }

    private func delete(_ spec: WidgetSpec) {
        do { try store.delete(id: spec.id); error = nil; reload() } catch { self.error = "\(error)" }
    }
}

/// The Widgetry editor wired to Tempo's calendar. Live preview uses your real upcoming events (read-only); with no
/// events it falls back to sample values.
struct CustomWidgetEditor: View {
    let spec: WidgetSpec
    var onClose: () -> Void
    @Environment(EventStoreManager.self) private var manager

    var body: some View {
        let from = Date(), to = Calendar.tempo.date(byAdding: .day, value: 7, to: from) ?? from
        let events = manager.eventAccess == .full ? EventReader().events(from: from, to: to, in: manager.activeSet) : []
        let source = TempoCustomData(events: events, access: manager.eventAccess)
        SpecEditor(spec: spec, source: source,
                   sample: events.isEmpty ? SpecTemplates.sample() : nil,
                   onSave: { saved in
                       do { try TempoSpecStore.shared.upsert(saved); onClose() } catch { NSLog("Widget save failed: \(error)") }
                   },
                   onCancel: onClose)
    }
}

#if os(macOS)
/// Content of the Mac "Widget Editor" window (opened with the spec's id).
struct WidgetEditorWindow: View {
    let id: UUID
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            if let spec = TempoSpecStore.shared.spec(id: id) {
                CustomWidgetEditor(spec: spec, onClose: { dismiss() })
            } else {
                ContentUnavailableView("Widget not found", systemImage: "square.dashed")
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }
}
#endif
