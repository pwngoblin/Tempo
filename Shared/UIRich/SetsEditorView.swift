import SwiftUI
import CalendarCore

/// Create/rename/delete Calendar Sets and choose which calendars each contains.
struct SetsEditorView: View {
    @Environment(EventStoreManager.self) private var manager
    @State private var drafts: [CalendarSet] = []

    var body: some View {
        List {
            ForEach($drafts) { $set in
                Section {
                    HStack {
                        Image(systemName: set.symbol).foregroundStyle(.secondary)
                        TextField("Name", text: $set.name)
                        Button(role: .destructive) { drafts.removeAll { $0.id == set.id } } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).accessibilityLabel("Delete \(set.name)")
                    }
                    ForEach(manager.calendars) { cal in
                        Toggle(isOn: Binding(
                            get: { set.contains(cal) },
                            set: { on in
                                if on { set.calendars.append(CalendarRef(cal)) }
                                else { set.calendars.removeAll { $0.id == cal.id || ($0.title == cal.title && $0.source == cal.source) } }
                            })) {
                            Label { Text(cal.title); Text(cal.source).foregroundStyle(.secondary) } icon: { Image(systemName: "circle.fill").foregroundStyle(Color(cal.color)) }
                        }
                    }
                }
            }
            Section {
                Button { drafts.append(CalendarSet(name: "New Set", symbol: "folder")) } label: { Label("Add Calendar Set", systemImage: "plus") }
            } footer: {
                Text("\"All\" always shows every calendar. Sets sync between your devices through iCloud key-value storage.")
            }
        }
        .onAppear { drafts = manager.customSets }
        .onChange(of: drafts) { _, new in manager.saveSets(new) }
    }
}
