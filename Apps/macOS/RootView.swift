import SwiftUI
import CalendarCore

struct RootView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } detail: {
            Group {
                if manager.eventAccess != .full { AccessPrompt() }
                else {
                    switch nav.mode {
                    case .day: TimeGridView(days: [nav.date])
                    case .week: TimeGridView(days: weekDays)
                    case .month: MonthView()
                    }
                }
            }
            .id(PrefsStore.shared.values.layoutKey)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    ControlGroup {
                        Button { nav.shift(-1) } label: { Image(systemName: "chevron.left") }.help("Previous")
                        Button("Today") { nav.date = .now }
                        Button { nav.shift(1) } label: { Image(systemName: "chevron.right") }.help("Next")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $nav.mode) { ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented)
                }
                ToolbarItem { SetPicker() }
                ToolbarItem { Button { nav.showQuickAdd = true } label: { Label("Quick Add", systemImage: "plus") }.help("Quick add (⌘K)") }
            }
        }
        .onChange(of: nav.settingsRequest) { _, _ in openSettings(); NSApp.activate(ignoringOtherApps: true) }
        .onAppear { TempoAppDelegate.openMain = { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) } }
        .animation(.snappy, value: nav.mode)
        .sheet(item: $nav.editor) { EventEditorView(target: $0).environment(manager) }
        .overlay(alignment: .top) { if nav.showQuickAdd { CommandBar() } }
        .alert("Couldn't save", isPresented: Binding(get: { manager.lastError != nil }, set: { _ in manager.lastError = nil })) {
            Button("OK") {}
        } message: { Text(manager.lastError ?? "") }
    }

    private var weekDays: [Date] {
        let cal = Calendar.tempo
        let start = cal.dateInterval(of: .weekOfYear, for: nav.date)?.start ?? cal.startOfDay(for: nav.date)
        let all = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        return PrefsStore.shared.values.workWeekOnly ? all.filter { !cal.isDateInWeekend($0) } : all
    }

    private var title: String {
        switch nav.mode {
        case .day: nav.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
        case .week: nav.date.formatted(.dateTime.month(.wide).year())
        case .month: nav.date.formatted(.dateTime.month(.wide).year())
        }
    }
}

struct Sidebar: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(EventStoreManager.self) private var manager
    @Environment(Navigator.self) private var nav

    var body: some View {
        @Bindable var nav = nav
        List(selection: Binding(get: { manager.activeSetID }, set: { if let id = $0 { manager.setActive(id) } })) {
            Section("Calendar Sets") {
                ForEach(manager.sets) { set in Label(set.name, systemImage: set.symbol).tag(set.id) }
            }
            Section {
                ForEach(manager.calendars) { c in
                    Toggle(isOn: Binding(get: { !manager.hiddenCalendarIDs.contains(c.id) }, set: { manager.setCalendar(c.id, visible: $0) })) {
                        Label { Text(c.title).foregroundStyle(manager.activeSet.contains(c) ? .primary : .tertiary) }
                        icon: { Image(systemName: "circle.fill").foregroundStyle(Color(c.color)) }
                    }
                    .toggleStyle(.checkbox)
                    .help("Show or hide this calendar in Tempo (the calendar itself is not changed)")
                }
            } header: {
                HStack {
                    Text("Calendars")
                    Spacer()
                    Button { openSettings() } label: { Image(systemName: "plus") }.buttonStyle(.borderless)
                        .help("Subscribe to a calendar by URL…").accessibilityLabel("Subscribe to a calendar")
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { MiniMonthView(selected: $nav.date).padding(10) }
    }
}

/// ⌘K / ⌘N floating command bar. Esc dismisses.
struct CommandBar: View {
    @Environment(Navigator.self) private var nav

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.15).ignoresSafeArea().onTapGesture { nav.showQuickAdd = false }
            QuickAddView { nav.showQuickAdd = false }
                .padding(14)
                .frame(width: 520)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.separator))
                .shadow(radius: 20, y: 8)
                .padding(.top, 70)
        }
        .onExitCommand { nav.showQuickAdd = false }
        .transition(.opacity)
    }
}
