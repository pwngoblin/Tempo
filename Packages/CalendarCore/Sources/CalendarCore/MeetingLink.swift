import Foundation

public enum MeetingProvider: String, Codable, Sendable, CaseIterable {
    case teams, zoom, webex, meet
    public var name: String {
        switch self {
        case .teams: "Teams"
        case .zoom: "Zoom"
        case .webex: "Webex"
        case .meet: "Google Meet"
        }
    }
    public var symbol: String { "video.fill" }
}

public struct MeetingLink: Codable, Hashable, Sendable {
    public var provider: MeetingProvider
    public var url: URL
    public init(provider: MeetingProvider, url: URL) { self.provider = provider; self.url = url }
}

/// Finds a video-meeting join link in an event's `url`, `location` and `notes`.
/// Only https (and `zoommtg`) URLs on exact provider domains are accepted, so a crafted
/// invite cannot make the "Join" button open an arbitrary scheme or look-alike host.
public enum MeetingLinkExtractor {
    public static func extract(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        if let url, let link = classify(url) { return link }
        for text in [location, notes] {
            guard let text, !text.isEmpty else { continue }
            for candidate in urls(in: text) { if let link = classify(candidate) { return link } }
        }
        return nil
    }

    static func urls(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let ns = text as NSString
        return detector.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap(\.url)
    }

    static func classify(_ original: URL) -> MeetingLink? {
        let url = unwrapSafeLink(original)
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if scheme == "zoommtg" || scheme == "zoomus" { return MeetingLink(provider: .zoom, url: url) }
        guard scheme == "https" else { return nil }

        func on(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }

        if (host == "teams.microsoft.com" && (path.hasPrefix("/l/meetup-join") || path.hasPrefix("/meet/")))
            || (host == "teams.live.com" && path.hasPrefix("/meet")) {
            return MeetingLink(provider: .teams, url: url)
        }
        if (on("zoom.us") || on("zoomgov.com")),
           path.hasPrefix("/j/") || path.hasPrefix("/my/") || path.hasPrefix("/wc/join") || path.hasPrefix("/s/") {
            return MeetingLink(provider: .zoom, url: url)
        }
        if on("webex.com"), path.contains("/meet") || path.contains("/join") || path.hasPrefix("/wbxmjs") {
            return MeetingLink(provider: .webex, url: url)
        }
        if host == "meet.google.com",
           path.range(of: #"^/[a-z]{3}-[a-z]{4}-[a-z]{3}"#, options: .regularExpression) != nil || path.hasPrefix("/lookup/") {
            return MeetingLink(provider: .meet, url: url)
        }
        return nil
    }

    /// Outlook rewrites links as `*.safelinks.protection.outlook.com/?url=<real>`.
    static func unwrapSafeLink(_ url: URL) -> URL {
        guard let host = url.host?.lowercased(), host.hasSuffix("safelinks.protection.outlook.com"),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let real = comps.queryItems?.first(where: { $0.name.lowercased() == "url" })?.value,
              let inner = URL(string: real) else { return url }
        return inner
    }
}
