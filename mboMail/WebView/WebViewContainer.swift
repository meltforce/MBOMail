import SwiftUI
import WebKit
import PDFKit

@MainActor
final class PendingTabNavigation {
    static let shared = PendingTabNavigation()
    var pendingURL: URL?
}

@MainActor
final class NewTabAction {
    static let shared = NewTabAction()
    private var handler: (() -> Void)?

    func register(_ action: @escaping () -> Void) {
        handler = action
    }

    func createNewTab() {
        handler?()
    }
}

struct WebViewContainer: NSViewRepresentable {

    @Binding var isLoading: Bool
    @Binding var error: Error?
    @Binding var isSessionExpired: Bool

    let downloadDelegate: DownloadDelegate
    let webViewStore: WebViewStore
    let appSettings: AppSettings

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }

    @Binding var hoveredLink: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = webViewStore.webView
        let coordinator = context.coordinator

        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator

        // Wire the JS→Swift message handler
        webViewStore.configureMessageHandler(coordinator)

        coordinator.onLoadingChanged = { loading in
            isLoading = loading
        }
        coordinator.onError = { err in
            error = err
        }
        coordinator.onSessionExpired = {
            isSessionExpired = true
        }
        coordinator.onLinkHover = { url in
            hoveredLink = url
        }
        coordinator.onUnreadCount = { [appSettings] count, subject, from in
            NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
            NotificationManager.shared.handleUnreadCountChange(count, subject: subject, from: from, settings: appSettings)
        }
        coordinator.onMessageId = { messageId in
            let link = "message:\(messageId)"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(link, forType: .string)
        }
        coordinator.onPageLoaded = { [webViewStore] in
            let css = UserDefaults.standard.string(forKey: "customCSS") ?? ""
            let js = UserDefaults.standard.string(forKey: "customJS") ?? ""
            webViewStore.injectCustomStyles(css: css)
            webViewStore.injectCustomScripts(js: js)
            webViewStore.startUnreadPollTimer()

            // Handle pending mailto compose (cold start from mailto: link)
            if let params = webViewStore.pendingMailtoParams {
                webViewStore.pendingMailtoParams = nil
                webViewStore.navigateToCompose(parameters: params)
            }
        }

        // Apply persisted appearance mode
        webViewStore.applyAppearance(appSettings.appearanceMode)

        // Load pending URL (from Cmd+click) or default mailbox.org
        if webView.url == nil {
            let url = PendingTabNavigation.shared.pendingURL ?? AppConstants.baseURL
            PendingTabNavigation.shared.pendingURL = nil
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}

@Observable
final class WebViewStore {

    let webView: WKWebView
    let userContentController: WKUserContentController
    private var unreadPollTimer: Timer?

    // MARK: - JS loaded from bundle resources

    static let linkHoverJS: String = loadBundleJS("link-hover")
    static let unreadObserverJS: String = loadBundleJS("unread-observer")

    private static func loadBundleJS(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("Missing JS resource: \(name).js")
            return ""
        }
        return source
    }

    deinit {
        unreadPollTimer?.invalidate()
    }

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.websiteDataStore = .default()

        let controller = WKUserContentController()
        config.userContentController = controller
        self.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true

        // Set custom User-Agent
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        wv.evaluateJavaScript("navigator.userAgent") { result, _ in
            if let ua = result as? String {
                wv.customUserAgent = ua + " MBOMail/\(appVersion)"
            }
        }

        // Restore persisted zoom level
        let zoom = UserDefaults.standard.double(forKey: "zoomLevel")
        wv.pageZoom = zoom > 0 ? zoom : 1.0

        self.webView = wv

        // Add permanent scripts
        addPermanentScripts()

        // Compile and apply tracker blocking rules if enabled
        if UserDefaults.standard.object(forKey: "trackerBlockingEnabled") == nil || UserDefaults.standard.bool(forKey: "trackerBlockingEnabled") {
            Task {
                await ContentBlocker.shared.compile()
                await ContentBlocker.shared.apply(to: controller)
            }
        }
    }

    // MARK: - Message Handler

    func configureMessageHandler(_ handler: WKScriptMessageHandler) {
        userContentController.removeScriptMessageHandler(forName: "mbomail")
        userContentController.add(handler, name: "mbomail")
    }

    // MARK: - Permanent Scripts

    private func addPermanentScripts() {
        let hoverScript = WKUserScript(
            source: Self.linkHoverJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        let unreadScript = WKUserScript(
            source: Self.unreadObserverJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(hoverScript)
        userContentController.addUserScript(unreadScript)
    }

    // MARK: - Native Unread Poll Timer

    /// JS snippet that reads the unread count from the DOM and posts it back to Swift.
    /// Called from a Swift Timer so it fires even when the window is minimized
    /// (WKWebView throttles its own setInterval when not visible).
    private static let unreadPollSnippet: String = loadBundleJS("unread-poll")

    func startUnreadPollTimer() {
        unreadPollTimer?.invalidate()
        unreadPollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.webView.evaluateJavaScript(Self.unreadPollSnippet)
            }
        }
    }

    func stopUnreadPollTimer() {
        unreadPollTimer?.invalidate()
        unreadPollTimer = nil
    }

    // MARK: - Custom CSS/JS Injection

    func injectCustomStyles(css: String) {
        guard !css.isEmpty else { return }
        let escaped = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let js = """
            (function() {
                var existing = document.getElementById('mbomail-custom-css');
                if (existing) existing.remove();
                var style = document.createElement('style');
                style.id = 'mbomail-custom-css';
                style.textContent = `\(escaped)`;
                document.head.appendChild(style);
            })();
            """
        webView.evaluateJavaScript(js)
    }

    func injectCustomScripts(js: String) {
        guard !js.isEmpty else { return }
        webView.evaluateJavaScript(js)
    }

    // MARK: - Copy Message Link

    func copyMessageLink() {
        let js = """
            (async function() {
                var selected = document.querySelector('.list-item.selected[data-cid]');
                if (!selected) return null;
                var cid = selected.dataset.cid;
                var lastDot = cid.lastIndexOf('.');
                var folder = cid.substring(0, lastDot);
                var id = cid.substring(lastDot + 1);
                var session = sessionStorage.getItem('sessionId');
                if (!session) return null;
                var resp = await fetch(
                    '/appsuite/api/mail?action=get&folder=' + encodeURIComponent(folder) +
                    '&id=' + id + '&session=' + session + '&unseen=true'
                );
                var data = await resp.json();
                var messageId = data.data && data.data.headers && data.data.headers['Message-ID'];
                if (messageId) {
                    window.webkit.messageHandlers.mbomail.postMessage({
                        type: 'messageId',
                        value: messageId
                    });
                }
                return messageId;
            })();
            """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Print

    func printPage() {
        // Extract the mail detail content from the iframe and print it
        let js = """
            (function() {
                var iframe = document.querySelector('iframe.mail-detail-frame');
                if (iframe && iframe.contentDocument) {
                    return iframe.contentDocument.documentElement.outerHTML;
                }
                return null;
            })();
            """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let html = result as? String, let self else { return }
            self.showPrintWindow(html: html)
        }
    }

    private var printWindow: NSWindow?
    private var printHelper: PrintHelper?

    @MainActor private func showPrintWindow(html: String) {
        let config = WKWebViewConfiguration()
        let printWV = WKWebView(frame: NSRect(x: 0, y: 0, width: 700, height: 900), configuration: config)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = printWV
        window.title = "Print"
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        window.orderBack(nil)
        self.printWindow = window

        // Use a helper to detect when content is loaded, then print
        let helper = PrintHelper(window: window) { [weak self] in
            self?.printWindow = nil
            self?.printHelper = nil
        }
        self.printHelper = helper
        printWV.navigationDelegate = helper

        printWV.loadHTMLString(html, baseURL: AppConstants.baseURL)
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
        webView.load(URLRequest(url: AppConstants.baseURL))
    }

    /// Mailto parameters waiting to be applied after OX finishes loading (cold start).
    var pendingMailtoParams: [String: String]?

    func navigateToCompose(parameters: [String: String] = [:]) {
        // Build JSON params for the JS side
        let jsonPairs = parameters.map { key, value -> String in
            let escapedValue = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            return "'\(key)': '\(escapedValue)'"
        }
        let jsonObj = "{\(jsonPairs.joined(separator: ", "))}"

        // If OX is loaded in the webview, trigger compose via JS.
        // Otherwise store params and apply after OX finishes loading.
        if let currentURL = webView.url,
           let host = currentURL.host,
           host.hasSuffix(AppConstants.hostSuffix) {
            let js = """
                (function() {
                    var params = \(jsonObj);
                    function tryCompose() {
                        // Wait for OX to be fully loaded
                        var composeBtn = document.querySelector('.primary-action .btn-primary, a[data-action="io.ox/mail/actions/compose"]');
                        if (!composeBtn) {
                            setTimeout(tryCompose, 300);
                            return;
                        }
                        // Click the compose button
                        composeBtn.click();
                        // Wait for compose dialog and fill fields
                        fillCompose(params, 0);
                    }
                    function fillCompose(params, attempt) {
                        if (attempt > 30) return; // give up after ~6s
                        var composeWin = document.querySelector('.io-ox-mail-compose-window');
                        if (!composeWin) {
                            setTimeout(function() { fillCompose(params, attempt + 1); }, 200);
                            return;
                        }
                        // Fill To field — OX uses a tokenfield input
                        if (params.to) {
                            var toInput = composeWin.querySelector('.tokenfield .token-input, .to-field input, [data-extension-id="to"] input');
                            if (toInput) {
                                toInput.focus();
                                toInput.value = params.to;
                                toInput.dispatchEvent(new Event('input', {bubbles: true}));
                                // Press Enter/comma to tokenize the address
                                toInput.dispatchEvent(new KeyboardEvent('keydown', {key: 'Enter', keyCode: 13, bubbles: true}));
                            }
                        }
                        if (params.subject) {
                            var subjectInput = composeWin.querySelector('input[name="subject"], .subject-field input, [data-extension-id="subject"] input');
                            if (subjectInput) {
                                subjectInput.focus();
                                subjectInput.value = params.subject;
                                subjectInput.dispatchEvent(new Event('input', {bubbles: true}));
                                subjectInput.dispatchEvent(new Event('change', {bubbles: true}));
                            }
                        }
                        if (params.body) {
                            var bodyFrame = composeWin.querySelector('iframe.mce-edit-area iframe, .editor iframe, iframe');
                            if (bodyFrame && bodyFrame.contentDocument) {
                                var bodyEl = bodyFrame.contentDocument.body;
                                if (bodyEl) {
                                    bodyEl.innerHTML = params.body.replace(/\\n/g, '<br>');
                                }
                            }
                        }
                    }
                    tryCompose();
                })();
                """
            webView.evaluateJavaScript(js)
        } else {
            pendingMailtoParams = parameters
        }
    }

    func applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .system:
            webView.appearance = nil
        case .light:
            webView.appearance = NSAppearance(named: .aqua)
        case .dark:
            webView.appearance = NSAppearance(named: .darkAqua)
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

// MARK: - Print Helper

@MainActor
final class PrintHelper: NSObject, WKNavigationDelegate {
    private let window: NSWindow
    private let onDone: () -> Void

    init(window: NSWindow, onDone: @escaping () -> Void) {
        self.window = window
        self.onDone = onDone
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                let pdfConfig = WKPDFConfiguration()
                webView.createPDF(configuration: pdfConfig) { [self] result in
                    guard let data = try? result.get() else {
                        self.window.close()
                        self.onDone()
                        return
                    }

                    // Write PDF to temp file and print via PDFDocument
                    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("mbomail-print.pdf")
                    try? data.write(to: tmpURL)

                    if let pdfDoc = PDFDocument(url: tmpURL),
                       let pdfView = PDFView(frame: NSRect(x: 0, y: 0, width: 700, height: 900)) as PDFView? {
                        pdfView.document = pdfDoc
                        pdfView.autoScales = true

                        let printOp = pdfDoc.printOperation(for: .shared, scalingMode: .pageScaleToFit, autoRotate: true)
                        printOp?.showsPrintPanel = true
                        printOp?.showsProgressPanel = true
                        printOp?.run()
                    }

                    self.window.close()
                    self.onDone()
                    try? FileManager.default.removeItem(at: tmpURL)
                }
            }
        }
    }
}
