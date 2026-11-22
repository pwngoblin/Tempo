import SwiftUI
import CalendarCore

// MARK: - Sections (composed differently on iOS and macOS)

struct AppearanceSection: View {
    @Bindable private var store = PrefsStore.shared
    var body: some View {
        Section("Appearance") {
            Picker("Theme", selection: $store.values.theme) { ForEach(ThemeChoice.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented)
            AccentPicker(selection: $store.values.accent)
        }
        Section("Time & dates") {
            Picker("Time format", selection: $store.values.timeFormat) { ForEach(TimeFormatChoice.allCases) { Text($0.title).tag($0) } }
            Picker("First day of week", selection: $store.values.weekStart) { ForEach(WeekStartChoice.allCases) { Text($0.title).tag($0) } }
            Toggle("Show week numbers", isOn: $store.values.showWeekNumbers)
        }
    }
}

struct AccentPicker: View {
    @Binding var selection: AccentChoice
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent color")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(AccentChoice.allCases) { a in
                    Button { selection = a } label: {
                        Circle().fill(a == .system ? AnyShapeStyle(AngularGradient(colors: [.blue, .purple, .pink, .orange, .green, .blue], center: .center)) : AnyShapeStyle(a.color))
                            .frame(width: 28, height: 28)
                            .overlay { if selection == a { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                            .frame(minWidth: 36, minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(a.title).accessibilityAddTraits(selection == a ? .isSelected : [])
                }
            }
        }
    }
}

struct LayoutSection: View {
    @Bindable private var store = PrefsStore.shared
    var body: some View {
        Section("Event style") {
            Picker("Density", selection: $store.values.density) { ForEach(DensityChoice.allCases) { Text($0.title).tag($0) } }
            Picker("Event blocks", selection: $store.values.blockStyle) { ForEach(BlockStyleChoice.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented)
            BlockPreview(style: store.values.blockStyle)
            Toggle("Show end time", isOn: $store.values.showEndTime)
            Toggle("Show locations", isOn: $store.values.showLocation)
            Toggle("Show Join button", isOn: $store.values.showMeetingBadge)
        }
        Section("Day & week grid") {
            VStack(alignment: .leading) {
                Text("Hour height")
                Slider(value: $store.values.hourHeightScale, in: 0.7...1.8, step: 0.1) { Text("Hour height") } minimumValueLabel: { Image(systemName: "arrow.down.right.and.arrow.up.left") } maximumValueLabel: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
            }
            Picker("Opens scrolled to", selection: $store.values.scrollToHour) {
                ForEach(0..<23, id: \.self) { h in Text(Calendar.tempo.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.hourText).tag(h) }
            }
            #if os(macOS)
            Toggle("Work week only (hide weekends)", isOn: $store.values.workWeekOnly)
            Toggle("Show all-day events strip", isOn: $store.values.showAllDayStrip)
            #endif
        }
    }
}

/// Live sample so every style choice is visible while choosing.
struct BlockPreview: View {
    let style: BlockStyleChoice
    var body: some View {
        HStack(spacing: 8) {
            ForEach([(Color.blue, "Standup"), (Color.orange, "Lunch"), (Color.purple, "Review")], id: \.1) { c, t in
                VStack(alignment: .leading, spacing: 1) { Text(t).font(.caption.weight(.semibold)); Text("10:00").font(.caption2).opacity(0.7) }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                    .eventBlock(c, style: style)
            }
        }
        .accessibilityHidden(true)
    }
}

struct ViewsSection: View {
    @Bindable private var store = PrefsStore.shared
    var body: some View {
        #if os(iOS)
        Section("Agenda") {
            Picker("Opens in", selection: $store.values.defaultViewPhone) {
                Text("Agenda").tag("agenda"); Text("Week").tag("week"); Text("Month").tag("month")
            }
            Picker("Days shown", selection: $store.values.agendaDays) { ForEach([7, 14, 30, 60], id: \.self) { Text("\($0) days").tag($0) } }
            Toggle("Show reminders", isOn: $store.values.showReminders)
        }
        #else
        Section("Main window") {
            Picker("Opens in", selection: $store.values.defaultViewMac) {
                Text("Day").tag("day"); Text("Week").tag("week"); Text("Month").tag("month")
            }
        }
        #endif
    }
}

struct NewEventsSection: View {
    @Environment(EventStoreManager.self) private var manager
    @Bindable private var store = PrefsStore.shared
    var body: some View {
        Section {
            Stepper(value: $store.values.defaultDurationMinutes, in: 5...480, step: 5) {
                Text("Default length: \(store.values.defaultDurationMinutes) min")
            }
            Picker("Default calendar", selection: Binding(get: { store.values.preferredCalendarID ?? "" }, set: { store.values.preferredCalendarID = $0.isEmpty ? nil : $0 })) {
                Text("Automatic").tag("")
                ForEach(manager.writableCalendars) { c in Text(c.title).tag(c.id) }
            }
            #if os(iOS)
            Toggle("Haptic feedback", isOn: $store.values.haptics)
            #endif
        } header: { Text("New events") } footer: {
            Text("Used when you type a phrase without #calendar or a time range, and when you click or drag in the grid.")
        }
    }
}

#if os(macOS)
import ServiceManagement

/// "Keep the menu bar running at login": registers the embedded helper as a login item.
struct LoginItemToggle: View {
    private static let service = SMAppService.loginItem(identifier: "com.local.tempo.menubar")
    @State private var enabled = LoginItemToggle.service.status == .enabled
    @State private var message: String?
    var body: some View {
        Toggle("Start menu bar at login", isOn: Binding(get: { enabled }, set: { on in
            do {
                if on { try Self.service.register() } else { try Self.service.unregister() }
                message = nil
            } catch { message = "Couldn't change the login item: \(error.localizedDescription)" }
            enabled = Self.service.status == .enabled
        }))
        if let message { Text(message).font(.footnote).foregroundStyle(.red) }
    }
}

struct MenuBarSection: View {
    @Bindable private var store = PrefsStore.shared
    var body: some View {
        Section {
            Toggle("Show in menu bar", isOn: $store.values.menuBarEnabled)
            LoginItemToggle()
            Toggle("Show event title", isOn: $store.values.menuBarShowTitle).disabled(!store.values.menuBarEnabled)
            Picker("Countdown format", selection: $store.values.menuBarFormat) { ForEach(MenuBarFormatChoice.allCases) { Text($0.title).tag($0) } }
                .disabled(!store.values.menuBarEnabled)
            Stepper(value: $store.values.menuBarMaxTitle, in: 8...60, step: 2) { Text("Title length: \(store.values.menuBarMaxTitle) characters") }
                .disabled(!store.values.menuBarEnabled || !store.values.menuBarShowTitle)
            Stepper(value: $store.values.joinLeadMinutes, in: 1...60) { Text("Show Join button \(store.values.joinLeadMinutes) min before") }
                .disabled(!store.values.menuBarEnabled)
        } header: { Text("Menu bar") } footer: { Text("The menu bar runs as its own small app, so it stays when you quit Tempo (stop it with Quit Menu Bar in its popover). Example: \(example)") }
    }
    private var example: String {
        let p = store.values
        let t = MenuBarFormat.compact(12 * 60, long: p.menuBarFormat == .long)
        return p.menuBarShowTitle ? "\(MenuBarFormat.trim("GRC Sync", p.menuBarMaxTitle)) · \(t)" : t
    }
}
#endif

/// Show/hide calendars inside Tempo (never changes the calendars themselves).
struct CalendarVisibilitySection: View {
    @Environment(EventStoreManager.self) private var manager
    var body: some View {
        Section {
            ForEach(Dictionary(grouping: manager.calendars, by: \.source).sorted { $0.key < $1.key }, id: \.key) { source, cals in
                DisclosureGroup(source.isEmpty ? "Other" : source) {
                    ForEach(cals) { c in
                        Toggle(isOn: Binding(get: { !manager.hiddenCalendarIDs.contains(c.id) }, set: { manager.setCalendar(c.id, visible: $0) })) {
                            Label { Text(c.title) } icon: { Image(systemName: "circle.fill").foregroundStyle(Color(c.color)) }
                        }
                    }
                }
            }
        } header: { Text("Visible calendars") } footer: {
            Text("Hidden calendars disappear from Tempo, its widgets and the menu bar. They stay untouched in the Calendar app.")
        }
    }
}

struct ResetSection: View {
    @State private var confirm = false
    var body: some View {
        Section {
            Button("Reset All Customization…", role: .destructive) { confirm = true }
                .confirmationDialog("Reset every Tempo setting to its default?", isPresented: $confirm, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { PrefsStore.shared.reset() }
                }
        } footer: { Text("Calendar Sets, subscriptions and your calendar data are not affected.") }
    }
}

// MARK: - Settings container

struct SettingsView: View {
    enum Page: Hashable { case appearance, layout, views, newEvents, calendars, sets, subscriptions }
    var start: Page?
    @State private var path: [Page] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        TabView {
            Form { AppearanceSection(); NewEventsSection(); ResetSection() }.formStyle(.grouped)
                .tabItem { Label("General", systemImage: "gearshape") }
            Form { ViewsSection(); LayoutSection() }.formStyle(.grouped)
                .tabItem { Label("Views", systemImage: "rectangle.split.3x1") }
            Form { MenuBarSection() }.formStyle(.grouped)
                .tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            Form { CalendarVisibilitySection() }.formStyle(.grouped)
                .tabItem { Label("Calendars", systemImage: "calendar") }
            SetsEditorView().tabItem { Label("Sets", systemImage: "square.stack") }
            SubscriptionsView().tabItem { Label("Subscriptions", systemImage: "dot.radiowaves.up.forward") }
        }
        .frame(width: 600, height: 560)
        #else
        NavigationStack(path: $path) {
            List {
                NavigationLink(value: Page.appearance) { Label("Appearance & Time", systemImage: "paintbrush") }
                NavigationLink(value: Page.layout) { Label("Event Style & Grid", systemImage: "rectangle.grid.1x2") }
                NavigationLink(value: Page.views) { Label("Agenda & Views", systemImage: "list.bullet.rectangle") }
                NavigationLink(value: Page.newEvents) { Label("New Events", systemImage: "plus.circle") }
                NavigationLink(value: Page.calendars) { Label("Visible Calendars", systemImage: "calendar") }
                NavigationLink(value: Page.sets) { Label("Calendar Sets", systemImage: "square.stack") }
                NavigationLink(value: Page.subscriptions) { Label("Subscribed Calendars", systemImage: "dot.radiowaves.up.forward") }
                Form { ResetSection() }.frame(height: 90).listRowInsets(EdgeInsets())
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Page.self) { page in
                Group {
                    switch page {
                    case .appearance: Form { AppearanceSection() }
                    case .layout: Form { LayoutSection() }
                    case .views: Form { ViewsSection() }
                    case .newEvents: Form { NewEventsSection() }
                    case .calendars: Form { CalendarVisibilitySection() }
                    case .sets: SetsEditorView()
                    case .subscriptions: SubscriptionsView()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(title(page))
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { if let start, path.isEmpty { path = [start] } }
        #endif
    }

    private func title(_ p: Page) -> String {
        switch p {
        case .appearance: "Appearance & Time"; case .layout: "Event Style & Grid"; case .views: "Agenda & Views"
        case .newEvents: "New Events"; case .calendars: "Visible Calendars"; case .sets: "Calendar Sets"; case .subscriptions: "Subscriptions"
        }
    }
}
