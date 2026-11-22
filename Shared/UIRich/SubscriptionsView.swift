import SwiftUI
import CalendarCore

/// Subscribe to an internet calendar (ICS feed) by address, and manage subscribed calendars.
/// EventKit can't create subscriptions itself, so the system Calendar confirms and performs it;
/// the calendar then shows up in Tempo (and its widgets / the watch) automatically.
struct SubscriptionsView: View {
    @Environment(EventStoreManager.self) private var manager
    @Environment(\.openURL) private var openURL
    @State private var address = ""
    @State private var message: String?
    @State private var messageIsError = false
    @State private var pendingRemoval: CalendarInfo?

    var body: some View {
        List {
            Section {
                TextField("Calendar address", text: $address, prompt: Text("https:// or webcal://"))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    #endif
                    .onSubmit(subscribe)
                Button("Subscribe…", action: subscribe).disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                if let message { Label(message, systemImage: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.footnote).foregroundStyle(messageIsError ? Color.red : Color.green) }
            } header: { Text("Add a subscription") } footer: {
                Text("The Calendar app asks you to confirm. Subscribed calendars are read-only and refresh automatically. Plain http:// feeds are refused.")
            }

            Section("Subscribed calendars") {
                if manager.subscribedCalendars.isEmpty {
                    Text("None yet").foregroundStyle(.secondary)
                }
                ForEach(manager.subscribedCalendars) { c in
                    HStack {
                        Image(systemName: "circle.fill").foregroundStyle(Color(c.color)).imageScale(.small)
                        VStack(alignment: .leading) { Text(c.title); Text(c.source).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        Button(role: .destructive) { pendingRemoval = c } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).accessibilityLabel("Unsubscribe from \(c.title)")
                    }
                }
            }
        }
        .confirmationDialog("Unsubscribe from “\(pendingRemoval?.title ?? "")”?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible) {
            Button("Unsubscribe", role: .destructive) {
                if let c = pendingRemoval {
                    do { try manager.removeCalendar(id: c.id); message = "Unsubscribed from \(c.title)."; messageIsError = false }
                    catch { message = error.localizedDescription; messageIsError = true }
                }
                pendingRemoval = nil
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #endif
    }

    private func subscribe() {
        switch CalendarSubscription.webcalURL(from: address) {
        case .success(let url):
            openURL(url)
            message = "Continue in Calendar, then come back — it will appear here."
            messageIsError = false
        case .failure(let f):
            message = f.localizedDescription
            messageIsError = true
        }
    }
}
