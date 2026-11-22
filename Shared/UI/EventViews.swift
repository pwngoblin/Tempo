import SwiftUI
import CalendarCore

/// Apple-Calendar-style row: start/end time column, calendar color bar, title and place.
struct EventRow: View {
    let event: EventItem
    var showJoin = true
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = 54

    var body: some View {
        let p = PrefsStore.shared.values
        HStack(alignment: .center, spacing: 10) {
            #if !os(watchOS)
            VStack(alignment: .trailing, spacing: 1) {
                if event.isAllDay { Text("all-day").font(.footnote).foregroundStyle(.secondary) }
                else {
                    Text(event.start.timeText).font(.subheadline.weight(.semibold)).monospacedDigit()
                    if p.showEndTime { Text(event.end.timeText).font(.caption).monospacedDigit().foregroundStyle(.secondary) }
                }
            }
            .frame(width: timeWidth, alignment: .trailing)
            #endif
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color(event.color)).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.body.weight(.medium)).lineLimit(2)
                #if os(watchOS)
                Text(event.timeRangeText).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                #else
                if p.showLocation, let place = event.location {
                    HStack(spacing: 3) { Image(systemName: "mappin.and.ellipse").imageScale(.small); Text(place).lineLimit(1) }
                        .font(.footnote).foregroundStyle(.secondary)
                }
                #endif
            }
            Spacer(minLength: 0)
            #if !os(watchOS)
            if showJoin, p.showMeetingBadge, let link = event.meetingLink { JoinButton(link: link) }
            #endif
        }
        .padding(.vertical, 2 + p.density.rowPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(event.timeRangeText)" + (event.location.map { ", \($0)" } ?? ""))
    }
}

#if !os(watchOS)
struct JoinButton: View {
    let link: MeetingLink
    var prominent = false
    var body: some View {
        Link(destination: link.url) {
            Label(prominent ? "Join \(link.provider.name)" : "Join", systemImage: link.provider.symbol)
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(prominent ? .regular : .small)
        .accessibilityLabel("Join \(link.provider.name) meeting")
    }
}
#endif

struct SetPicker: View {
    @Environment(EventStoreManager.self) private var manager
    var body: some View {
        #if os(watchOS)
        Picker(selection: Binding(get: { manager.activeSetID }, set: { manager.setActive($0) })) {
            ForEach(manager.sets) { Label($0.name, systemImage: $0.symbol).tag($0.id) }
        } label: { Label("Set", systemImage: manager.activeSet.symbol) }
        #else
        Menu {
            ForEach(manager.sets) { set in
                Button { manager.setActive(set.id) } label: {
                    if set.id == manager.activeSetID { Label(set.name, systemImage: "checkmark") }
                    else { Label(set.name, systemImage: set.symbol) }
                }
            }
        } label: {
            HStack(spacing: 4) { Image(systemName: manager.activeSet.symbol); Text(manager.activeSet.name) }
        }
        .accessibilityLabel("Calendar set: \(manager.activeSet.name)")
        #endif
    }
}

struct AccessPrompt: View {
    @Environment(EventStoreManager.self) private var manager
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
            Text("Calendar access needed").font(.headline)
            Text(manager.eventAccess == .notDetermined
                 ? "Tempo reads and writes events on this device only."
                 : "Enable Calendars for Tempo in Settings › Privacy.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if manager.eventAccess == .notDetermined {
                Button("Allow Access") { Task { await manager.requestAccess() } }.buttonStyle(.borderedProminent)
            }
        }.padding()
    }
}
