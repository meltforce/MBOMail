import Foundation

enum AppConstants {
    /// Base URL for the mailbox.org web app.
    static let baseURL: URL = {
        guard let url = URL(string: "https://app.mailbox.org/appsuite/") else {
            fatalError("Invalid mailbox.org base URL")
        }
        return url
    }()

    /// Host suffix used to identify mailbox.org domains (includes subdomains).
    static let hostSuffix = "mailbox.org"

    /// User-visible service name for loading/error messages.
    static let serviceName = "mailbox.org"
}
