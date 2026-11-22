import Foundation

/// Validates a user-typed calendar feed address and turns it into the `webcal://` URL that the system
/// Calendar handles ("Subscribe to calendar"). EventKit has no API to create a subscribed calendar,
/// so the system performs the subscription and the calendar then appears in Tempo like any other.
///
/// Accepted: `webcal://`, `webcals://`, `https://`, or a bare `host/path.ics` (assumed https).
/// Rejected: plain `http://` (feeds can carry private events), any other scheme, missing host, or absurd length.
public enum CalendarSubscription {
    public enum Failure: Error, Equatable, LocalizedError {
        case empty, insecure, unsupportedScheme, invalid
        public var errorDescription: String? {
            switch self {
            case .empty: "Enter a calendar address."
            case .insecure: "Use an https:// or webcal:// address; plain http feeds aren't accepted."
            case .unsupportedScheme: "Only webcal:// and https:// addresses can be subscribed."
            case .invalid: "That doesn't look like a valid calendar address."
            }
        }
    }

    public static func webcalURL(from input: String) -> Result<URL, Failure> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .failure(.empty) }
        guard text.count <= 2048, !text.contains(where: { $0.isWhitespace || $0.isNewline }) else { return .failure(.invalid) }

        var candidate = text
        if let range = text.range(of: "://") {
            let scheme = text[..<range.lowerBound].lowercased()
            switch scheme {
            case "webcal", "webcals", "https": break
            case "http": return .failure(.insecure)
            default: return .failure(.unsupportedScheme)
            }
        } else if text.contains(":") && !text.contains("/") {
            return .failure(.unsupportedScheme)    // e.g. "javascript:…", "mailto:…"
        } else {
            candidate = "https://" + text
        }

        guard var comps = URLComponents(string: candidate), let host = comps.host, host.contains("."), !host.hasPrefix(".") else {
            return .failure(.invalid)
        }
        comps.scheme = "webcal"
        guard let url = comps.url else { return .failure(.invalid) }
        return .success(url)
    }
}
