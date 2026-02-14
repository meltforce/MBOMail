import Foundation

actor URLResolver {

    static let shared = URLResolver()

    private static let shortenerDomains: Set<String> = [
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd",
        "buff.ly", "j.mp", "lnkd.in", "db.tt", "qr.ae", "adf.ly",
        "bl.ink", "rb.gy", "shorturl.at", "cutt.ly", "short.io",
        "rebrand.ly", "tiny.cc", "v.gd", "t.ly", "s.id", "clck.ru",
        "yourls.org", "surl.li", "link.chtbl.com", "amzn.to", "amzn.eu",
        "youtu.be", "redd.it", "flip.it", "zpr.io"
    ]

    private var cache: [String: String] = [:]
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.httpMaximumConnectionsPerHost = 2
        // Allow redirects to be followed automatically — we compare final URL
        session = URLSession(configuration: config)
    }

    static func isShortened(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let host = url.host?.lowercased() else { return false }
        return shortenerDomains.contains(host) || shortenerDomains.contains(where: { host.hasSuffix(".\($0)") })
    }

    func resolve(_ urlString: String) async -> String? {
        if let cached = cache[urlString] { return cached }

        // Upgrade http to https (ATS blocks plain HTTP)
        let secureURLString = urlString.hasPrefix("http://")
            ? "https://" + urlString.dropFirst("http://".count)
            : urlString

        guard let url = URL(string: secureURLString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await session.data(for: request)
            if let finalURL = response.url?.absoluteString,
               finalURL != urlString, finalURL != secureURLString {
                cache[urlString] = finalURL
                return finalURL
            }
        } catch {}

        return nil
    }
}
