import XCTest
@testable import CalendarCore

final class MeetingLinkTests: XCTestCase {
    func link(_ s: String) -> MeetingLink? { MeetingLinkExtractor.extract(url: nil, location: nil, notes: s) }

    func testProviders() {
        XCTAssertEqual(link("Join: https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc/0?context=x")?.provider, .teams)
        XCTAssertEqual(link("https://us02web.zoom.us/j/123456789?pwd=abc")?.provider, .zoom)
        XCTAssertEqual(link("https://acme.webex.com/meet/jdoe")?.provider, .webex)
        XCTAssertEqual(link("https://meet.google.com/abc-defg-hij")?.provider, .meet)
    }
    func testURLFieldWinsOverNotes() {
        let l = MeetingLinkExtractor.extract(url: URL(string: "https://meet.google.com/abc-defg-hij"), location: nil, notes: "https://zoom.us/j/1")
        XCTAssertEqual(l?.provider, .meet)
    }
    func testLocationIsScanned() {
        XCTAssertEqual(MeetingLinkExtractor.extract(url: nil, location: "https://zoom.us/j/99", notes: nil)?.provider, .zoom)
    }
    func testLookalikeAndInsecureRejected() {
        XCTAssertNil(link("https://evilzoom.us/j/123"))
        XCTAssertNil(link("https://zoom.us.evil.com/j/123"))
        XCTAssertNil(link("http://zoom.us/j/123"))
        XCTAssertNil(link("https://meet.google.com/landing"))
        XCTAssertNil(link("see https://example.com/agenda"))
    }
    func testSafeLinksUnwrapped() {
        let wrapped = "https://eur01.safelinks.protection.outlook.com/?url=https%3A%2F%2Fzoom.us%2Fj%2F42&data=x"
        XCTAssertEqual(link(wrapped)?.provider, .zoom)
    }
}

final class AgendaTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func ev(_ id: String, _ startMin: Int, _ endMin: Int, allDay: Bool = false) -> EventItem {
        EventItem(eventID: id, title: id, start: t0.addingTimeInterval(Double(startMin) * 60), end: t0.addingTimeInterval(Double(endMin) * 60), isAllDay: allDay)
    }
    func at(_ m: Int) -> Date { t0.addingTimeInterval(Double(m) * 60) }

    func testCurrentNextFree() {
        let e = [ev("a", 10, 40), ev("b", 60, 90), ev("day", 0, 1440, allDay: true)]
        XCTAssertEqual(Agenda.current(e, at: at(20))?.eventID, "a")
        XCTAssertEqual(Agenda.next(e, after: at(20))?.eventID, "b")
        XCTAssertNil(Agenda.freeUntil(e, at: at(20)))
        XCTAssertEqual(Agenda.freeUntil(e, at: at(45)), at(60))
        XCTAssertNil(Agenda.current(e, at: at(5)), "all-day events never count as current")
    }
    func testBusyUntilChainsBackToBack() {
        let e = [ev("a", 10, 40), ev("b", 40, 70), ev("c", 90, 100)]
        XCTAssertEqual(Agenda.busyUntil(e, at: at(20)), at(70))
    }
    func testBusyBlocksMerge() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let day = cal.startOfDay(for: t0)
        let h = { (x: Double) in day.addingTimeInterval(x * 3600) }
        let e = [EventItem(eventID: "a", title: "a", start: h(9), end: h(10)), EventItem(eventID: "b", title: "b", start: h(9.5), end: h(11)),
                 EventItem(eventID: "c", title: "c", start: h(13), end: h(14))]
        XCTAssertEqual(Agenda.busyBlocks(e, on: day, calendar: cal), [DateInterval(start: h(9), end: h(11)), DateInterval(start: h(13), end: h(14))])
    }
    func testLayoutPlacesOverlapsSideBySide() {
        let placed = Agenda.layout([ev("a", 0, 60), ev("b", 30, 90), ev("c", 120, 150)])
        let by = Dictionary(uniqueKeysWithValues: placed.map { ($0.event.eventID, $0) })
        XCTAssertEqual(by["a"]?.columns, 2); XCTAssertEqual(by["b"]?.columns, 2)
        XCTAssertNotEqual(by["a"]?.column, by["b"]?.column)
        XCTAssertEqual(by["c"]?.columns, 1)
    }
    func testTimelinePlanIsBoundedAndSorted() {
        let events = (0..<50).map { ev("e\($0)", 10 + $0 * 30, 30 + $0 * 30) }
        let plan = TimelinePlanner.plan(events: events, now: at(0), maxEntries: 8, horizon: 12 * 3600, minReload: 900)
        XCTAssertEqual(plan.entries.count, 8)
        XCTAssertEqual(plan.entries, plan.entries.sorted())
        XCTAssertGreaterThanOrEqual(plan.reloadAfter, at(15))
    }
}

final class SetAndLinkTests: XCTestCase {
    func testSetMatchingFallsBackToTitleAndSource() {
        let set = CalendarSet(name: "Work", calendars: [CalendarRef(id: "old-id", title: "Work", source: "iCloud")])
        XCTAssertTrue(set.contains(CalendarInfo(id: "new-id", title: "Work", source: "iCloud", color: .fallback, allowsModify: true)))
        XCTAssertFalse(set.contains(CalendarInfo(id: "x", title: "Home", source: "iCloud", color: .fallback, allowsModify: true)))
        XCTAssertTrue(CalendarSet.all.contains(CalendarInfo(id: "x", title: "Home", source: "", color: .fallback, allowsModify: true)))
    }
    func testStoreCyclesThroughAllAndCustom() {
        let d = UserDefaults(suiteName: "tempo.tests.\(UUID())")!
        let store = CalendarSetStore(defaults: d)
        let work = CalendarSet(name: "Work"), home = CalendarSet(name: "Personal")
        store.save([work, home])
        XCTAssertEqual(store.active.id, CalendarSet.allID)
        XCTAssertEqual(store.cycle().id, work.id); XCTAssertEqual(store.cycle().id, home.id); XCTAssertEqual(store.cycle().id, CalendarSet.allID)
        XCTAssertEqual(store.cycle(by: -1).id, home.id)
    }
    func testDeepLinkRoundTrip() {
        let id = UUID()
        for link in [DeepLink.today, .settings, .day("2026-11-25"), .event("AB12/CD"), .set(id), .add("Gym tomorrow 6pm")] {
            XCTAssertEqual(DeepLink(url: link.url), link, "\(link.url)")
        }
        XCTAssertNil(DeepLink(url: URL(string: "https://example.com")!))
        XCTAssertNil(DeepLink(url: URL(string: "tempo://day/not-a-date")!))
    }
}

final class SubscriptionTests: XCTestCase {
    func ok(_ s: String) -> String? { if case .success(let u) = CalendarSubscription.webcalURL(from: s) { u.absoluteString } else { nil } }
    func err(_ s: String) -> CalendarSubscription.Failure? { if case .failure(let e) = CalendarSubscription.webcalURL(from: s) { e } else { nil } }

    func testAcceptedForms() {
        XCTAssertEqual(ok("webcal://example.com/cal.ics"), "webcal://example.com/cal.ics")
        XCTAssertEqual(ok("https://example.com/feeds/a.ics?token=abc"), "webcal://example.com/feeds/a.ics?token=abc")
        XCTAssertEqual(ok("webcals://example.com/cal.ics"), "webcal://example.com/cal.ics")
        XCTAssertEqual(ok("  example.com/cal.ics \n"), "webcal://example.com/cal.ics")
    }
    func testRejected() {
        XCTAssertEqual(err(""), .empty)
        XCTAssertEqual(err("http://example.com/cal.ics"), .insecure)
        XCTAssertEqual(err("ftp://example.com/cal.ics"), .unsupportedScheme)
        XCTAssertEqual(err("file:///etc/passwd"), .unsupportedScheme)
        XCTAssertEqual(err("javascript:alert(1)"), .unsupportedScheme)
        XCTAssertEqual(err("https://localhost/cal.ics"), .invalid)
        XCTAssertEqual(err("https://exa mple.com/x.ics"), .invalid)
        XCTAssertEqual(err(String(repeating: "a", count: 3000)), .invalid)
    }
}

final class VisibilityTests: XCTestCase {
    func testHideAndShowRoundTrip() {
        let v = CalendarVisibility(defaults: UserDefaults(suiteName: "tempo.tests.vis.\(UUID())")!)
        XCTAssertTrue(v.hidden.isEmpty)
        v.setHidden("a", true); v.setHidden("b", true)
        XCTAssertEqual(v.hidden, ["a", "b"])
        v.setHidden("a", false)
        XCTAssertEqual(v.hidden, ["b"])
    }
}
