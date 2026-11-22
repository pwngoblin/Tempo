import Foundation

/// `tempo://today`, `tempo://day/2026-11-25`, `tempo://event/<id>`, `tempo://set/<uuid>`, `tempo://add?text=...`
public enum DeepLink: Equatable, Sendable {
    case today
    case day(String)          // yyyy-MM-dd
    case event(String)        // EventItem.eventID
    case set(UUID)
    case add(String?)
    case settings

    public var url: URL {
        var c = URLComponents()
        c.scheme = AppGroup.urlScheme
        switch self {
        case .today: c.host = "today"
        case .settings: c.host = "settings"
        case .day(let d): c.host = "day"; c.path = "/" + d
        case .event(let id): c.host = "event"; c.path = "/" + id.replacingOccurrences(of: "/", with: "%2F")
        case .set(let id): c.host = "set"; c.path = "/" + id.uuidString
        case .add(let t): c.host = "add"; if let t { c.queryItems = [URLQueryItem(name: "text", value: t)] }
        }
        return c.url ?? URL(string: "\(AppGroup.urlScheme)://today")!
    }

    public init?(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return nil }
        let arg = url.path.split(separator: "/").first.map(String.init)?.removingPercentEncoding
        switch url.host {
        case "today": self = .today
        case "settings": self = .settings
        case "day": guard let arg, Self.isISODay(arg) else { return nil }; self = .day(arg)
        case "event": guard let arg, !arg.isEmpty else { return nil }; self = .event(arg)
        case "set": guard let arg, let id = UUID(uuidString: arg) else { return nil }; self = .set(id)
        case "add":
            let text = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "text" }?.value
            self = .add(text)
        default: return nil
        }
    }

    public static func day(_ date: Date, calendar: Calendar = .current) -> DeepLink {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return .day(String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0))
    }

    public static func date(from iso: String, calendar: Calendar = .current) -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    private static func isISODay(_ s: String) -> Bool {
        s.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}
