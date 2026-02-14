import WebKit

/// Experimental POC for WKWebExtension support.
/// The WKWebExtension API (introduced in Safari 18 / macOS 15.4+) is not yet
/// available in the current Xcode SDK. This stub provides the UI scaffolding
/// so that extension management can be implemented when the API ships.
///
/// Note on Safari extensions: Safari "Add to Dock" web apps share Safari's
/// installed extensions automatically, but standalone WKWebView apps cannot
/// access Safari's extensions. The WKWebExtension API will allow loading
/// .appex bundles directly — but extensions must be built specifically for
/// the host app (or distributed as universal web extensions).
///
/// Password managers (1Password, Bitwarden) already work via macOS system-wide
/// autofill (Passwords app / Keychain) in any WKWebView — no extension needed.
@MainActor
final class ExtensionManager {

    static let shared = ExtensionManager()

    struct LoadedExtension: Identifiable {
        let id = UUID()
        let name: String
        let bundleURL: URL
    }

    private(set) var extensions: [LoadedExtension] = []

    @discardableResult
    func loadExtension(from bundleURL: URL) throws -> String {
        guard Bundle(url: bundleURL) != nil else {
            throw ExtensionError.invalidBundle
        }

        // TODO: When WKWebExtension API is available in the SDK:
        // let ext = try WKWebExtension(resourceBaseURL: bundle.resourceURL ?? bundleURL)
        // let context = WKWebExtensionContext(for: ext)
        // try await controller.add(context)

        let name = bundleURL.deletingPathExtension().lastPathComponent
        extensions.append(LoadedExtension(name: name, bundleURL: bundleURL))
        return name
    }

    func removeExtension(_ ext: LoadedExtension) {
        extensions.removeAll { $0.id == ext.id }
    }

    func removeAll() {
        extensions.removeAll()
    }

    enum ExtensionError: LocalizedError {
        case invalidBundle
        case apiUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidBundle: "The selected file is not a valid app extension bundle."
            case .apiUnavailable: "WKWebExtension API is not available in the current SDK."
            }
        }
    }
}
