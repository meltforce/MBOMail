import Cocoa
import WebKit

private nonisolated(unsafe) var composeAssociatedKey: UInt8 = 0

@MainActor
final class ComposeWindowManager {

    static let shared = ComposeWindowManager()

    private var windows: [NSWindow] = []

    func openComposeWindow(url: URL? = nil, parameters: [String: String] = [:]) {
        let composeURL: URL
        if let url {
            composeURL = url
        } else {
            var fragment = "#!!&app=io.ox/mail&folder=default0/INBOX&action=compose"
            for (key, value) in parameters {
                fragment += "&\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
            }
            composeURL = URL(string: "https://app.mailbox.org/appsuite/\(fragment)")!
        }

        let config = WKWebViewConfiguration()
        config.processPool = WebViewStore.sharedProcessPool
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.allowsBackForwardNavigationGestures = false

        let delegate = ComposeWebViewDelegate()
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.title = "Compose"
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("ComposeWindow-\(windows.count)")

        // Store delegate reference on the window to prevent deallocation
        objc_setAssociatedObject(window, &composeAssociatedKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Observe window close to clean up
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let closedWindow = notification.object as? NSWindow else { return }
            MainActor.assumeIsolated {
                self?.windows.removeAll { $0 === closedWindow }
            }
        }

        windows.append(window)
        window.makeKeyAndOrderFront(nil)

        webView.load(URLRequest(url: composeURL))
    }
}

@MainActor
final class ComposeWebViewDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }

        if let host = url.host, host.hasSuffix("mailbox.org") {
            return .allow
        }
        if url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" {
            return .allow
        }

        // External links open in default browser
        if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            return .cancel
        }

        return .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if !navigationResponse.canShowMIMEType {
            return .download
        }
        return .allow
    }

    // MARK: - Downloads

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = DownloadDelegate.shared
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = DownloadDelegate.shared
    }

    // MARK: - WKUIDelegate (file upload)

    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.begin { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }
}
