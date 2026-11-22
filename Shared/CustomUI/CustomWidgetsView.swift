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
        List {
            Section {
                ForEach(specs) { spec in
                    Button { edit(spec) } label: {
                        HStack(spacing: 12) {
                            thumbnail(spec)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spec.name).font(.body.weight(.medium))
                                Text("Tap to edit").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") { edit(spec) }
                        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(spec) }
                        Button("Delete", systemImage: "trash", role: .destructive) { delete(spec) }
                    }
                }
                .onDelete { idx in idx.map { specs[$0] }.forEach(delete) }
                Menu {
                    ForEach(SpecTemplates.all) { t in Button(t.name) { create(from: t) } }
                } label: { Label("New Widget", systemImage: "plus.circle.fill") }
            } header: { Text("Your widgets") } footer: {
                Text("Design a layout here, then add the **Custom** widget from the widget gallery and choose it. Data comes from your active Calendar Set; nothing leaves your device.")
            }
            if let error { Section { Text(error).foregroundStyle(.red).font(.footnote) } }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
        .navigationTitle("Custom Widgets")
        .onAppear(perform: reload)
        #if !os(macOS)
        .sheet(item: $editing, onDismiss: reload) { spec in
            NavigationStack { CustomWidgetEditor(spec: spec, onClose: { editing = nil }) }
                .environment(manager)
        }
        #endif
    }

    private func thumbnail(_ spec: WidgetSpec) -> some View {
        SpecView(spec: spec, context: SpecTemplates.sample())
            .padding(10).frame(width: 158, height: 158, alignment: .topLeading)
            .scaleEffect(0.34, anchor: .topLeading).frame(width: 54, height: 54, alignment: .topLeading)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
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
