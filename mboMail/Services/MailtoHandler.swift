import Foundation

enum MailtoHandler {

    /// Parse a mailto: URL into parameters suitable for OX compose.
    /// Supports: to, cc, bcc, subject, body per RFC 6068.
    static func parse(_ url: URL) -> [String: String] {
        var params: [String: String] = [:]

        let urlString = url.absoluteString
        guard urlString.lowercased().hasPrefix("mailto:") else { return params }

        let afterScheme = String(urlString.dropFirst("mailto:".count))

        // Split path from query
        let parts = afterScheme.split(separator: "?", maxSplits: 1)
        let recipient = String(parts[0])
            .removingPercentEncoding ?? String(parts[0])

        if !recipient.isEmpty {
            params["to"] = recipient
        }

        // Parse query parameters
        if parts.count > 1 {
            let query = String(parts[1])
            for pair in query.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                guard let key = kv.first else { continue }
                let value = kv.count > 1
                    ? (String(kv[1]).removingPercentEncoding ?? String(kv[1]))
                    : ""

                let keyStr = String(key).lowercased()
                switch keyStr {
                case "to":
                    if let existing = params["to"], !existing.isEmpty {
                        params["to"] = existing + "," + value
                    } else {
                        params["to"] = value
                    }
                case "cc", "bcc", "subject", "body":
                    params[keyStr] = value
                default:
                    break
                }
            }
        }

        return params
    }
}
