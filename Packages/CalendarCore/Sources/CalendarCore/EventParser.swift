import Foundation

public struct ParsedEvent: Equatable, Sendable {
    public enum TokenKind: String, Sendable { case calendar, location, date, time, duration }
    public struct Token: Equatable, Sendable {
        public let kind: TokenKind
        public let range: NSRange          // UTF-16 range in the original input
    }

    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var calendarHint: String?
    public var hasExplicitDate: Bool
    public var hasExplicitTime: Bool
    public var tokens: [Token]

    /// e.g. "Fri, Nov 28 · 10:00 – 10:45" for the live preview pill.
    public var summary: String {
        let day = start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        if isAllDay { return "\(day) · All day" }
        let s = start.formatted(.dateTime.hour().minute())
        let e = end.formatted(.dateTime.hour().minute())
        return "\(day) · \(s) – \(e)"
    }
}

/// Deterministic, offline natural-language event parser.
///
/// Custom rules handle the common shapes (`#calendar`, `@location`, today/tomorrow/weekdays,
/// `Nov 25`, ISO dates, `18:00-19:30`, `10am`, `45m`, `1h30m`, `all day`). `NSDataDetector` is the
/// fallback for date phrasing the rules do not cover. Every recognised span is blanked out of the
/// working string; whatever is left becomes the title.
///
/// Time heuristics: a bare hour 1–6 is PM, 7–11 is AM (`at 5` → 17:00); 24-hour input (`18:00`,
/// `06:00`) and explicit am/pm are always honoured. "next fri" means strictly after today; a bare
/// weekday may mean today. A date with no time becomes all-day (or 09:00 if a duration is given).
public struct EventParser: Sendable {
    public var calendar: Calendar
    public var defaultDuration: TimeInterval

    public init(calendar: Calendar = .current, defaultDuration: TimeInterval = 3600) {
        self.calendar = calendar; self.defaultDuration = defaultDuration
    }

    // MARK: Patterns
    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: [.caseInsensitive]) }
    private static let months = #"(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"#
    private static let tag = rx(#"(?<![\w])#([\p{L}\p{N}_\-]+)"#)
    private static let location = rx(#"(?<![\w])@(?:"([^"]+)"|([\p{L}][\p{L}\p{N}_.\-]*))"#)
    private static let iso = rx(#"(?<![\w-])(\d{4})-(\d{1,2})-(\d{1,2})(?![\w-])"#)
    private static let monthDay = rx(#"(?<![\w])"# + months + #"\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?![\w:])"#)
    private static let dayMonth = rx(#"(?<![\w:.])(\d{1,2})(?:st|nd|rd|th)?\s+"# + months + #"\.?(?![\w])"#)
    private static let relDay = rx(#"(?<![\w])(day after tomorrow|tomorrow|tmrw|tmr|today|tonight|tonite)(?![\w])"#)
    private static let inN = rx(#"(?<![\w])in\s+(\d{1,3})\s*(days?|weeks?)(?![\w])"#)
    private static let weekday = rx(#"(?<![\w])(?:(next|this|on)\s+)?(monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thu|friday|fri|saturday|sat|sunday|sun)(?![\w])"#)
    private static let range = rx(#"(?<![\w:.])(from\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\s*(?:-|–|—|to|until|till)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?(?![\w:])"#)
    private static let single = rx(#"(?<![\w:.])(?:(at|@)\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?(?![\w:])"#)
    private static let noonMidnight = rx(#"(?<![\w])(noon|midnight)(?![\w])"#)
    private static let duration = rx(#"(?<![\w:.])(?:for\s+)?(?:(\d+(?:[.,]\d+)?)\s*(?:hours?|hrs?|h)(?:\s*(\d{1,2})\s*(?:minutes?|mins?|m))?|(\d{1,3})\s*(?:minutes?|mins?|m))(?![\w])"#)
    private static let allDay = rx(#"(?<![\w])all[\s-]?day(?![\w])"#)

    private static let monthIndex: [String: Int] = ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
    private static let weekdayIndex: [String: Int] = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]  // Calendar weekday numbering

    // MARK: Working string
    private struct Work {
        let original: String
        var text: String
        var tokens: [ParsedEvent.Token] = []
        init(_ s: String) { original = s; text = s }
        var ns: NSString { text as NSString }
        var full: NSRange { NSRange(location: 0, length: ns.length) }

        func first(_ rx: NSRegularExpression, where valid: (NSTextCheckingResult) -> Bool = { _ in true }) -> NSTextCheckingResult? {
            rx.matches(in: text, range: full).first(where: valid)
        }
        func group(_ m: NSTextCheckingResult, _ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r)
        }
        mutating func consume(_ m: NSTextCheckingResult, _ kind: ParsedEvent.TokenKind) { consume(range: m.range, kind) }
        mutating func consume(range: NSRange, _ kind: ParsedEvent.TokenKind) {
            tokens.append(.init(kind: kind, range: range))
            text = ns.replacingCharacters(in: range, with: String(repeating: " ", count: range.length))
        }
    }

    // MARK: Parse
    public func parse(_ input: String, now: Date = Date()) -> ParsedEvent? {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var w = Work(input)
        let today = calendar.startOfDay(for: now)

        // #calendar
        var calendarHint: String?
        if let m = w.first(Self.tag) {
            calendarHint = w.group(m, 1)?.replacingOccurrences(of: "_", with: " ")
            w.consume(m, .calendar)
        }
        // @location or @"multi word"
        var place: String?
        if let m = w.first(Self.location) {
            let raw = w.group(m, 1) ?? w.group(m, 2) ?? ""
            place = raw.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
            w.consume(m, .location)
        }

        // ---- Date ----
        var day: Date?
        var weekdayOnly = false
        var tonight = false

        if let m = w.first(Self.iso), let y = Int(w.group(m, 1)!), let mo = Int(w.group(m, 2)!), let d = Int(w.group(m, 3)!),
           let date = makeDate(y, mo, d) {
            day = date; w.consume(m, .date)
        } else if let m = w.first(Self.monthDay), let mo = month(w.group(m, 1)), let d = Int(w.group(m, 2)!),
                  let date = upcoming(mo, d, from: today) {
            day = date; w.consume(m, .date)
        } else if let m = w.first(Self.dayMonth), let d = Int(w.group(m, 1)!), let mo = month(w.group(m, 2)),
                  let date = upcoming(mo, d, from: today) {
            day = date; w.consume(m, .date)
        } else if let m = w.first(Self.inN), let n = Int(w.group(m, 1)!) {
            let unit = w.group(m, 2)!.lowercased().hasPrefix("w") ? 7 : 1
            day = calendar.date(byAdding: .day, value: n * unit, to: today); w.consume(m, .date)
        } else if let m = w.first(Self.relDay) {
            switch w.group(m, 1)!.lowercased() {
            case "today": day = today
            case "tonight", "tonite": day = today; tonight = true
            case "day after tomorrow": day = calendar.date(byAdding: .day, value: 2, to: today)
            default: day = calendar.date(byAdding: .day, value: 1, to: today)
            }
            w.consume(m, .date)
        } else if let m = w.first(Self.weekday), let target = Self.weekdayIndex[String(w.group(m, 2)!.lowercased().prefix(3))] {
            let modifier = w.group(m, 1)?.lowercased()
            let current = calendar.component(.weekday, from: today)
            var delta = (target - current + 7) % 7
            if modifier == "next" && delta == 0 { delta = 7 }
            day = calendar.date(byAdding: .day, value: delta, to: today)
            weekdayOnly = modifier != "next"
            w.consume(m, .date)
        }

        // Fallback: let NSDataDetector try phrases the rules above did not cover ("11/25/2026", "next month").
        var detectedMinutes: Int?
        if day == nil, w.first(Self.monthDay) == nil, w.first(Self.dayMonth) == nil,   // rules already claimed (and rejected) those
           let hit = detectDate(in: w.text) {
            day = makeDate(hit.parts.year ?? 0, hit.parts.month ?? 0, hit.parts.day ?? 0)
            if hit.hasTime { detectedMinutes = (hit.parts.hour ?? 0) * 60 + (hit.parts.minute ?? 0) }
            w.consume(range: hit.range, hit.hasTime ? .time : .date)
        }

        // ---- Time ----
        var startMin: Int? = detectedMinutes
        var endMin: Int?
        if let m = w.first(Self.range, where: { rangeIsTime($0, in: w) }) {
            let sh = w.group(m, 2)!, eh = w.group(m, 5)!
            if let r = resolveRange(startHour: sh, startMin: w.group(m, 3), startMer: w.group(m, 4),
                                    endHour: eh, endMin: w.group(m, 6), endMer: w.group(m, 7)) {
                startMin = r.0; endMin = r.1; w.consume(m, .time)
            }
        }
        if startMin == nil, let m = w.first(Self.single, where: { singleIsTime($0, in: w) }),
           let hour = hour24(w.group(m, 2)!, meridiem: w.group(m, 4)) {
            startMin = hour * 60 + (Int(w.group(m, 3) ?? "0") ?? 0); w.consume(m, .time)
        }
        if startMin == nil, let m = w.first(Self.noonMidnight) {
            startMin = w.group(m, 1)!.lowercased() == "noon" ? 12 * 60 : 0; w.consume(m, .time)
        }

        // ---- Duration / all-day ----
        var durationSeconds: TimeInterval?
        if let m = w.first(Self.duration) {
            if let h = w.group(m, 1) {
                let hours = Double(h.replacingOccurrences(of: ",", with: ".")) ?? 0
                durationSeconds = hours * 3600 + Double(w.group(m, 2) ?? "0")! * 60
            } else if let mins = w.group(m, 3) { durationSeconds = Double(mins)! * 60 }
            if let d = durationSeconds, d > 0 { w.consume(m, .duration) } else { durationSeconds = nil }
        }
        var forcedAllDay = false
        if let m = w.first(Self.allDay) { forcedAllDay = true; w.consume(m, .duration) }

        // ---- Assemble ----
        if tonight && startMin == nil { startMin = 20 * 60 }
        let hasTime = startMin != nil
        var isAllDay = forcedAllDay
        var start: Date
        var end: Date

        if let startMin, !isAllDay {
            var base = day ?? today
            var s = at(minutes: startMin, on: base)
            if day == nil, s <= now { base = calendar.date(byAdding: .day, value: 1, to: today)!; s = at(minutes: startMin, on: base) }
            else if weekdayOnly, s <= now { base = calendar.date(byAdding: .day, value: 7, to: base)!; s = at(minutes: startMin, on: base) }
            start = s
            if let endMin { end = at(minutes: endMin, on: base) }
            else { end = start.addingTimeInterval(durationSeconds ?? defaultDuration) }
        } else if let day {
            if forcedAllDay || durationSeconds == nil {
                isAllDay = true; start = day
                end = calendar.date(byAdding: .day, value: 1, to: day)!.addingTimeInterval(-1)
            } else {
                start = at(minutes: 9 * 60, on: day); end = start.addingTimeInterval(durationSeconds!)
            }
        } else {
            let comps = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            start = calendar.date(byAdding: .hour, value: 1, to: calendar.date(from: comps)!)!
            end = start.addingTimeInterval(durationSeconds ?? defaultDuration)
        }

        return ParsedEvent(
            title: cleanTitle(w.text), start: start, end: end, isAllDay: isAllDay,
            location: (place?.isEmpty == false) ? place : nil, calendarHint: calendarHint,
            hasExplicitDate: day != nil, hasExplicitTime: hasTime, tokens: w.tokens)
    }

    // MARK: Helpers
    /// Date-only extraction (time of day is handled by the rules; the detector's default 12:00 is ignored).
    private func detectDate(in text: String) -> (parts: DateComponents, range: NSRange, hasTime: Bool)? {
        guard let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let ns = text as NSString
        guard let m = d.matches(in: text, range: NSRange(location: 0, length: ns.length)).first, let date = m.date else { return nil }
        // Skip matches that are really bare times ("5pm"); the time rules own those.
        let matched = ns.substring(with: m.range)
        guard matched.range(of: #"[A-Za-z]{3,}|[/.\-]\d"#, options: .regularExpression) != nil else { return nil }
        let hasTime = matched.range(of: #"\d\s*[ap]\.?m|\d:\d\d"#, options: [.regularExpression, .caseInsensitive]) != nil
        // NSDataDetector reports in the system zone: read the wall-clock parts there, rebuild in ours.
        var detectorCal = Calendar(identifier: .gregorian); detectorCal.timeZone = m.timeZone ?? .current
        return (detectorCal.dateComponents([.year, .month, .day, .hour, .minute], from: date), m.range, hasTime)
    }

    private func month(_ s: String?) -> Int? { s.flatMap { Self.monthIndex[String($0.lowercased().prefix(3))] } }

    private func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date? {
        guard let date = calendar.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year == y && c.month == m && c.day == d) ? date : nil   // rejects Feb 30 etc.
    }

    /// Next occurrence of month/day on or after `today` (rolls to next year if already past).
    private func upcoming(_ m: Int, _ d: Int, from today: Date) -> Date? {
        let y = calendar.component(.year, from: today)
        if let this = makeDate(y, m, d), this >= today { return this }
        return makeDate(y + 1, m, d)
    }

    private func at(minutes: Int, on day: Date) -> Date {
        let d = calendar.date(byAdding: .day, value: minutes / 1440, to: day)!
        let m = minutes % 1440
        return calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: d)!
    }

    private func hour24(_ raw: String, meridiem: String?) -> Int? {
        guard let h = Int(raw), (0...23).contains(h) || (meridiem != nil && (1...12).contains(h)) else { return nil }
        if let mer = meridiem?.lowercased().first {
            guard (1...12).contains(h) else { return nil }
            return mer == "a" ? (h == 12 ? 0 : h) : (h == 12 ? 12 : h + 12)
        }
        if raw.hasPrefix("0") || h == 0 || h >= 13 || h == 12 { return h }
        return h <= 6 ? h + 12 : h
    }

    private func rangeIsTime(_ m: NSTextCheckingResult, in w: Work) -> Bool {
        let hasFrom = w.group(m, 1) != nil
        let hasColon = w.group(m, 3) != nil || w.group(m, 6) != nil
        let hasMer = w.group(m, 4) != nil || w.group(m, 7) != nil
        guard hasFrom || hasColon || hasMer else { return false }
        for i in [3, 6] { if let s = w.group(m, i), (Int(s) ?? 99) > 59 { return false } }
        return true
    }

    private func singleIsTime(_ m: NSTextCheckingResult, in w: Work) -> Bool {
        guard w.group(m, 1) != nil || w.group(m, 3) != nil || w.group(m, 4) != nil else { return false }
        if let s = w.group(m, 3), (Int(s) ?? 99) > 59 { return false }
        return true
    }

    /// Resolves "10-11am", "11-1pm", "10am-11", "10pm-1am", "18:00-19:30" into minutes since midnight.
    private func resolveRange(startHour: String, startMin: String?, startMer: String?,
                              endHour: String, endMin: String?, endMer: String?) -> (Int, Int)? {
        let sm = Int(startMin ?? "0") ?? 0, em = Int(endMin ?? "0") ?? 0
        let sMer = startMer ?? endMer, eMer = endMer ?? startMer
        guard var s = hour24(startHour, meridiem: sMer), var e = hour24(endHour, meridiem: eMer) else { return nil }
        let flip = { (h: Int) -> Int in (h + 12) % 24 }
        if startMer == nil, endMer != nil, s * 60 + sm >= e * 60 + em, hour24(startHour, meridiem: nil) != nil,
           let alt = Optional(flip(s)), alt * 60 + sm < e * 60 + em { s = alt }
        if endMer == nil, startMer != nil, e * 60 + em <= s * 60 + sm,
           let alt = Optional(flip(e)), alt * 60 + em > s * 60 + sm { e = alt }
        var start = s * 60 + sm, end = e * 60 + em
        if end <= start { end += 1440 }   // crosses midnight
        start = max(0, start)
        return (start, end)
    }

    private func cleanTitle(_ s: String) -> String {
        var t = s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let junk = CharacterSet(charactersIn: "-–—,:;@ ")
        let connectors: Set<String> = ["at", "on", "from", "to", "until", "till", "for", "by", "in", "this", "next", "@"]
        while true {
            t = t.trimmingCharacters(in: junk)
            if let last = t.split(separator: " ").last, connectors.contains(last.lowercased()) {
                t = String(t.dropLast(last.count))
            } else { break }
        }
        return t.isEmpty ? "New Event" : t
    }
}
