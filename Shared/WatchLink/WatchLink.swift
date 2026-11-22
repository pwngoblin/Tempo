import Foundation
import Observation
import WatchConnectivity
import CalendarCore

/// iPhone <-> Watch bridge. EventKit is read-only on watchOS, so:
///  • watch → phone: quick-add phrases (`transferUserInfo`, queued + guaranteed delivery); the phone parses and saves.
///  • phone → watch: Calendar Set definitions (`updateApplicationContext`; the watch has its own App Group).
///  • phone → watch: a short result string for the quick-add ("Added Gym" / error).
@MainActor @Observable
final class WatchLink: NSObject {
    static let shared = WatchLink()
    private(set) var lastAck: String?
    /// iOS: called for each phrase received from the watch (phrase, time it was spoken).
    @ObservationIgnored var onAddRequest: ((String, Date) -> String)?
    /// watchOS: called after new set definitions were imported.
    @ObservationIgnored var onSetsImported: (() -> Void)?

    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func sendAdd(_ text: String) {
        session?.transferUserInfo(["add": text, "at": Date().timeIntervalSince1970])
    }

    func pushSets() {
        #if os(iOS)
        guard let session, session.activationState == .activated, session.isWatchAppInstalled,
              let data = CalendarSetStore().exportPayload() else { return }
        try? session.updateApplicationContext(["sets": data])
        #endif
    }

    fileprivate func handle(userInfo: [String: Any]) {
        if let text = userInfo["add"] as? String {
            let at = (userInfo["at"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            let result = onAddRequest?(text, at) ?? "iPhone app not ready"
            #if os(iOS)
            session?.transferUserInfo(["ack": result])
            #endif
        }
        if let ack = userInfo["ack"] as? String { lastAck = ack }
    }

    fileprivate func handle(context: [String: Any]) {
        if let data = context["sets"] as? Data, CalendarSetStore().importPayload(data) { onSetsImported?() }
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if activationState == .activated {
                self.pushSets()
                #if os(watchOS)
                self.handle(context: session.receivedApplicationContext)
                #endif
            }
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let info = userInfo
        Task { @MainActor in self.handle(userInfo: info) }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let ctx = applicationContext
        Task { @MainActor in self.handle(context: ctx) }
    }
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) { Task { @MainActor in self.pushSets() } }
    #endif
}
