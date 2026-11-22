import SwiftUI
import CalendarCore

/// Read-only event card (Apple Calendar style): title, when, where, join, then Edit.
/// iOS presents it in a sheet; macOS in a popover (pass `onEdit` there).
struct EventDetailView: View {
    let event: EventItem
    var onEdit: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false

    var body: some View {
        #if os(iOS)
        NavigationStack { card.navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if event.canModify { ToolbarItem(placement: .primaryAction) { Button("Edit") { editing = true } } }
            }
            .sheet(isPresented: $editing, onDismiss: { dismiss() }) { EventEditorView(target: .edit(event)) }
        }
        #else
        card.frame(width: 320)
        #endif
    }

    private var card: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(event.color)).frame(width: 5).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        Text(event.start.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .foregroundStyle(.secondary)
                        Text(event.timeRangeText).monospacedDigit()
                    }
                }
                if let link = event.meetingLink { JoinButton(link: link, prominent: true).frame(maxWidth: .infinity) }
                if let place = event.location {
                    Divider()
                    Link(destination: mapsURL(place)) { Label(place, systemImage: "mappin.and.ellipse") }
                }
                Divider()
                Label(event.calendarTitle, systemImage: "circle.fill").foregroundStyle(Color(event.color))
                    .labelStyle(.titleAndIcon).imageScale(.small)
                if event.hasRecurrence { Label("Repeating", systemImage: "repeat").foregroundStyle(.secondary) }
                if let n = event.attendeeCount { Label(n == 1 ? "1 person invited" : "\(n) people invited", systemImage: "person.2").foregroundStyle(.secondary) }
                if let notes = event.notes {
                    Divider()
                    Text(notes).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
                #if os(macOS)
                if event.canModify, let onEdit { Button("Edit…") { onEdit() }.padding(.top, 4) }
                #endif
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func mapsURL(_ place: String) -> URL {
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [URLQueryItem(name: "q", value: place)]
        return c.url ?? URL(string: "https://maps.apple.com/")!
    }
}
