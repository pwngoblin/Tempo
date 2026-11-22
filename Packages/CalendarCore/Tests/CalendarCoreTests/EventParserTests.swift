import XCTest
@testable import CalendarCore

final class EventParserTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; c.locale = Locale(identifier: "en_US"); return c }()
    /// Saturday 2026-11-21 10:00 UTC
    var now: Date { date(2026, 11, 21, 10, 0) }
    var parser: EventParser { EventParser(calendar: cal) }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    func parse(_ s: String) -> ParsedEvent { parser.parse(s, now: now)! }

    func testBlankIsNil() { XCTAssertNil(parser.parse("   ", now: now)) }

    func testTomorrowRangeAndCalendarTag() {
        let p = parse("Gym tomorrow 18:00-19:30 #Personal")
        XCTAssertEqual(p.title, "Gym")
        XCTAssertEqual(p.start, date(2026, 11, 22, 18, 0))
        XCTAssertEqual(p.end, date(2026, 11, 22, 19, 30))
        XCTAssertEqual(p.calendarHint, "Personal")
        XCTAssertFalse(p.isAllDay)
    }

    func testWeekdayTimeAndDuration() {
        let p = parse("Sync with team Fri 10am 45m")
        XCTAssertEqual(p.title, "Sync with team")
        XCTAssertEqual(p.start, date(2026, 11, 27, 10, 0))
        XCTAssertEqual(p.end, date(2026, 11, 27, 10, 45))
    }

    func testBareTimeLaterTodayStaysToday() {
        let p = parse("Lunch at 12")
        XCTAssertEqual(p.title, "Lunch")
        XCTAssertEqual(p.start, date(2026, 11, 21, 12, 0))
        XCTAssertEqual(p.end, date(2026, 11, 21, 13, 0))
    }

    func testPastTimeRollsToTomorrow() {
        XCTAssertEqual(parse("Call 9am").start, date(2026, 11, 22, 9, 0))
    }

    func testBareHeuristicAtFiveIsPM() { XCTAssertEqual(parse("Pickup at 5").start, date(2026, 11, 21, 17, 0)) }

    func testMonthNameLocationAndPM() {
        let p = parse("Dentist Nov 25 3pm @Dr_Smith")
        XCTAssertEqual(p.title, "Dentist")
        XCTAssertEqual(p.start, date(2026, 11, 25, 15, 0))
        XCTAssertEqual(p.location, "Dr Smith")
    }

    func testQuotedLocation() { XCTAssertEqual(parse(#"Demo tomorrow 2pm @"Room 4B""#).location, "Room 4B") }

    func testISODateIsAllDay() {
        let p = parse("Holiday 2026-12-24")
        XCTAssertTrue(p.isAllDay)
        XCTAssertEqual(p.title, "Holiday")
        XCTAssertEqual(p.start, date(2026, 12, 24))
    }

    func testAllDayKeyword() { XCTAssertTrue(parse("Conference tomorrow all day").isAllDay) }

    func testCrossMidnightRange() {
        let p = parse("Party 10pm-1am tomorrow")
        XCTAssertEqual(p.start, date(2026, 11, 22, 22, 0))
        XCTAssertEqual(p.end, date(2026, 11, 23, 1, 0))
    }

    func testSharedMeridiemRanges() {
        let a = parse("Workshop tomorrow 11-1pm")
        XCTAssertEqual(a.start, date(2026, 11, 22, 11, 0)); XCTAssertEqual(a.end, date(2026, 11, 22, 13, 0))
        let b = parse("Block tomorrow 10-11am")
        XCTAssertEqual(b.start, date(2026, 11, 22, 10, 0)); XCTAssertEqual(b.end, date(2026, 11, 22, 11, 0))
    }

    func testNextWeekdayIsStrictlyAfterToday() {
        let p = parse("Review 2h next sat")
        XCTAssertEqual(p.start, date(2026, 11, 28, 9, 0))
        XCTAssertEqual(p.end, date(2026, 11, 28, 11, 0))
    }

    func testBareWeekdayMatchingTodayWithFutureTime() { XCTAssertEqual(parse("Brunch sat 3pm").start, date(2026, 11, 21, 15, 0)) }

    func testCompoundDuration() {
        let p = parse("Planning monday 9:30 1h30m")
        XCTAssertEqual(p.start, date(2026, 11, 23, 9, 30)); XCTAssertEqual(p.end, date(2026, 11, 23, 11, 0))
        XCTAssertEqual(p.title, "Planning")
    }

    func testTonightDefaultsTo2000() {
        let p = parse("Dinner tonight")
        XCTAssertEqual(p.start, date(2026, 11, 21, 20, 0)); XCTAssertEqual(p.title, "Dinner")
    }

    func testInNDays() { XCTAssertEqual(parse("Yoga in 3 days 7am").start, date(2026, 11, 24, 7, 0)) }

    func testPlainNumbersAreNotTimes() {
        let p = parse("Room 5 standup")
        XCTAssertEqual(p.title, "Room 5 standup"); XCTAssertFalse(p.hasExplicitTime); XCTAssertFalse(p.hasExplicitDate)
    }

    func testDataDetectorFallbackHandlesNumericDates() {
        let p = parser.parse("Tax deadline 12/31/2027 9am", now: now)!
        XCTAssertEqual(p.title, "Tax deadline")
        XCTAssertEqual(cal.dateComponents([.year, .month, .day, .hour], from: p.start), DateComponents(year: 2027, month: 12, day: 31, hour: 9))
    }

    func testInvalidDateRejected() { XCTAssertFalse(parse("Thing Feb 30").hasExplicitDate) }

    func testNoiseOnlyGivesFallbackTitle() { XCTAssertEqual(parse("tomorrow 9am").title, "New Event") }

    func testTokensCoverRecognisedSpans() {
        let s = "Gym tomorrow 18:00-19:30 #Personal"
        let p = parse(s)
        XCTAssertEqual(Set(p.tokens.map(\.kind)), [.date, .time, .calendar])
        let ns = s as NSString
        XCTAssertEqual(p.tokens.first { $0.kind == .calendar }.map { ns.substring(with: $0.range) }, "#Personal")
    }
}
