import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {

    @Binding var isLoading: Bool
    @Binding var error: Error?
    @Binding var isSessionExpired: Bool

    let downloadDelegate: DownloadDelegate
    let webViewStore: WebViewStore

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = webViewStore.webView
        let coordinator = context.coordinator

        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator

        coordinator.onLoadingChanged = { loading in
            isLoading = loading
        }
        coordinator.onError = { err in
            error = err
        }
        coordinator.onSessionExpired = {
            isSessionExpired = true
        }

        // Load mailbox.org
        let url = URL(string: "https://app.mailbox.org/appsuite/")!
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}

@Observable
final class WebViewStore {

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.isElementFullscreenEnabled = true
        config.websiteDataStore = .default()

        let controller = WKUserContentController()
        config.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true

        // Set custom User-Agent
        wv.evaluateJavaScript("navigator.userAgent") { result, _ in
            if let ua = result as? String {
                wv.customUserAgent = ua + " mboMail/1.0"
            }
        }

        // Restore persisted zoom level
        let zoom = UserDefaults.standard.double(forKey: "zoomLevel")
        wv.pageZoom = zoom > 0 ? zoom : 1.0

        self.webView = wv
    }

    func reload() {
        webView.reload()
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func loadMailboxOrg() {
        let url = URL(string: "https://app.mailbox.org/appsuite/")!
        webView.load(URLRequest(url: url))
    }

    func navigateToCompose(parameters: [String: String] = [:]) {
        var fragment = "#!!&app=io.ox/mail&folder=default0/INBOX&action=compose"
        for (key, value) in parameters {
            fragment += "&\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }
        let urlString = "https://app.mailbox.org/appsuite/\(fragment)"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }

    func setZoom(_ level: Double) {
        webView.pageZoom = level
        UserDefaults.standard.set(level, forKey: "zoomLevel")
    }

    var currentZoom: Double {
        webView.pageZoom
    }
}
