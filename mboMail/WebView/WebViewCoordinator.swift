import SwiftUI
import WebKit

@MainActor
final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private let parent: WebViewContainer

    var onLoadingChanged: ((Bool) -> Void)?
    var onError: ((Error) -> Void)?
    var onSessionExpired: (() -> Void)?
    var onLinkHover: ((String) -> Void)?
    var onUnreadCount: ((_ count: Int, _ subject: String, _ from: String) -> Void)?
    var onMessageId: ((String) -> Void)?
    var onPageLoaded: (() -> Void)?

    init(_ parent: WebViewContainer) {
        self.parent = parent
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }

        // Allow mailbox.org URLs
        if let host = url.host, host.hasSuffix("mailbox.org") {
            // Cmd+click on mailbox.org link → open in new tab
            if navigationAction.navigationType == .linkActivated,
               navigationAction.modifierFlags.contains(.command) {
                openURLInNewTab(url)
                return .cancel
            }
            return .allow
        }

        // Allow about:blank and other internal schemes
        if url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" {
            return .allow
        }

        // Open external links in default browser
        if navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            return .cancel
        }

        // Allow other navigations (redirects, form submissions within the page)
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChanged?(true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChanged?(false)
        detectSessionState(webView)

        // Re-inject permanent scripts and custom CSS/JS after each navigation
        webView.evaluateJavaScript(WebViewStore.linkHoverJS)
        webView.evaluateJavaScript(WebViewStore.unreadObserverJS)
        onPageLoaded?()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoadingChanged?(false)
        onError?(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChanged?(false)
        onError?(error)
    }

    // MARK: - Downloads

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = parent.downloadDelegate
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = parent.downloadDelegate
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if !navigationResponse.canShowMIMEType {
            return .download
        }
        return .allow
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if let host = url.host, host.hasSuffix("mailbox.org") {
                // mailbox.org popup: load in existing webView
                webView.load(navigationAction.request)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }

    // MARK: - File Upload

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

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "linkHover":
                let url = body["url"] as? String ?? ""
                onLinkHover?(url)
            case "unreadCount":
                let count = body["count"] as? Int ?? 0
                let subject = body["subject"] as? String ?? ""
                let from = body["from"] as? String ?? ""
                onUnreadCount?(count, subject, from)
            case "messageId":
                let value = body["value"] as? String ?? ""
                onMessageId?(value)
            default:
                break
            }
        }
    }

    // MARK: - New Tab

    private func openURLInNewTab(_ url: URL) {
        PendingTabNavigation.shared.pendingURL = url
        NewTabAction.shared.createNewTab()
    }

    // MARK: - Session Detection

    private func detectSessionState(_ webView: WKWebView) {
        guard let url = webView.url else { return }
        let urlString = url.absoluteString

        // If URL is the base appsuite URL without an app hash, the session expired
        let isOnLoginPage = urlString.contains("/appsuite/") && !urlString.contains("#!!&app=")
        // Also check for the signin path
        let isOnSignin = urlString.contains("/appsuite/signin")

        if isOnLoginPage || isOnSignin {
            onSessionExpired?()
        }
    }
}
