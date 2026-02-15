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
        coordinator.onPageLoaded = { [webViewStore, appSettings] in
            let css = UserDefaults.standard.string(forKey: "customCSS") ?? ""
            let js = UserDefaults.standard.string(forKey: "customJS") ?? ""
            webViewStore.injectCustomStyles(css: css)
            webViewStore.injectCustomScripts(js: js)
            webViewStore.syncComposeFlag(appSettings.composeInSeparateWindow)
            webViewStore.startUnreadPollTimer()
        }

        // Load pending URL (from Cmd+click) or default mailbox.org
        if webView.url == nil {
            let url = PendingTabNavigation.shared.pendingURL ?? URL(string: "https://app.mailbox.org/appsuite/")!
            PendingTabNavigation.shared.pendingURL = nil
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}

@Observable
final class WebViewStore {

    static let sharedProcessPool = WKProcessPool()

    let webView: WKWebView
    let userContentController: WKUserContentController
    private var unreadPollTimer: Timer?

    // MARK: - JS Constants

    static let linkHoverJS = """
        (function() {
            if (window._mboLinkHoverInstalled) return;
            window._mboLinkHoverInstalled = true;

            function postHover(url) {
                window.webkit.messageHandlers.mbomail.postMessage({
                    type: 'linkHover',
                    url: url
                });
            }

            // Listen on the main document
            document.addEventListener('mouseover', function(e) {
                var link = e.target.closest('a[href]');
                if (link) postHover(link.href);
            }, true);
            document.addEventListener('mouseout', function(e) {
                var link = e.target.closest('a[href]');
                if (link) postHover('');
            }, true);

            // Inject hover listeners into iframes (mail detail frames)
            function injectIntoIframe(iframe) {
                try {
                    var doc = iframe.contentDocument;
                    if (!doc || doc._mboHoverInjected) return;
                    doc._mboHoverInjected = true;
                    doc.addEventListener('mouseover', function(e) {
                        var link = e.target.closest('a[href]');
                        if (link) postHover(link.href);
                    }, true);
                    doc.addEventListener('mouseout', function(e) {
                        var link = e.target.closest('a[href]');
                        if (link) postHover('');
                    }, true);
                } catch(e) {}
            }

            // Inject into existing iframes
            document.querySelectorAll('iframe').forEach(function(f) {
                if (f.contentDocument) injectIntoIframe(f);
                f.addEventListener('load', function() { injectIntoIframe(f); });
            });

            // Watch for new iframes being added
            var obs = new MutationObserver(function(mutations) {
                mutations.forEach(function(m) {
                    m.addedNodes.forEach(function(n) {
                        if (n.tagName === 'IFRAME') {
                            if (n.contentDocument) injectIntoIframe(n);
                            n.addEventListener('load', function() { injectIntoIframe(n); });
                        }
                        if (n.querySelectorAll) {
                            n.querySelectorAll('iframe').forEach(function(f) {
                                if (f.contentDocument) injectIntoIframe(f);
                                f.addEventListener('load', function() { injectIntoIframe(f); });
                            });
                        }
                    });
                });
            });
            obs.observe(document.body, { childList: true, subtree: true });
        })();
        """

    static let composeInterceptJS = """
        (function() {
            if (window._mboComposeInterceptInstalled) return;
            window._mboComposeInterceptInstalled = true;
            window._mboComposeInSeparateWindow = false;

            function notify(action) {
                console.log('[MBOMail] compose intercept: ' + action);
                window.webkit.messageHandlers.mbomail.postMessage({
                    type: 'composeRequest',
                    action: action || 'compose',
                    url: window.location.href
                });
            }

            // 1. Intercept clicks (capture phase, before OX handles them)
            document.addEventListener('click', function(e) {
                if (!window._mboComposeInSeparateWindow) return;
                var el = e.target;
                while (el && el !== document.body) {
                    // OX compose button: .primary-action > .btn-group > button.btn-primary
                    if (el.closest && el.closest('.primary-action')) {
                        e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
                        notify('compose-btn');
                        return;
                    }
                    // OX reply/forward: button[data-action="io.ox/mail/actions/reply|reply-all|forward"]
                    var da = el.getAttribute && el.getAttribute('data-action');
                    if (da && /^io\\.ox\\/mail\\/actions\\/(reply|reply-all|forward)$/.test(da)) {
                        e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
                        notify('click:' + da);
                        return;
                    }
                    el = el.parentElement;
                }
            }, true);

            // 2. Intercept 'c' keyboard shortcut (OX compose hotkey)
            document.addEventListener('keydown', function(e) {
                if (!window._mboComposeInSeparateWindow) return;
                if (e.key === 'c' && !e.ctrlKey && !e.metaKey && !e.altKey && !e.shiftKey) {
                    var tag = (e.target.tagName || '').toLowerCase();
                    if (tag !== 'input' && tag !== 'textarea' && !e.target.isContentEditable) {
                        e.preventDefault();
                        e.stopPropagation();
                        e.stopImmediatePropagation();
                        notify('compose-key');
                    }
                }
            }, true);

            // 3. Safety net: if OX compose window appears in DOM despite interception,
            //    close it and open native window instead
            var composeObserver = new MutationObserver(function(mutations) {
                if (!window._mboComposeInSeparateWindow) return;
                for (var i = 0; i < mutations.length; i++) {
                    var added = mutations[i].addedNodes;
                    for (var j = 0; j < added.length; j++) {
                        var node = added[j];
                        if (node.nodeType !== 1) continue;
                        var isCompose = node.classList && node.classList.contains('io-ox-mail-compose-window');
                        if (!isCompose && node.querySelector) {
                            isCompose = !!node.querySelector('.io-ox-mail-compose-window');
                        }
                        if (isCompose) {
                            console.log('[MBOMail] compose DOM appeared, closing and routing to native window');
                            // Find and click the close button on the OX compose window
                            var win = node.classList.contains('io-ox-mail-compose-window') ? node : node.querySelector('.io-ox-mail-compose-window');
                            if (win) {
                                var closeBtn = win.querySelector('.window-close, [data-action="close"]');
                                if (closeBtn) closeBtn.click();
                                else win.remove();
                            }
                            notify('dom-fallback');
                            return;
                        }
                    }
                }
            });
            if (document.body) {
                composeObserver.observe(document.body, { childList: true, subtree: true });
            }

            console.log('[MBOMail] compose intercept installed');
        })();
        """

    static let unreadObserverJS = """
        (function() {
            // Clean up previous observers/timers to prevent duplicates on re-injection
            if (window._mboUnreadInterval) clearInterval(window._mboUnreadInterval);
            if (window._mboUnreadObserver) window._mboUnreadObserver.disconnect();
            if (window._mboDebounceTimer) clearTimeout(window._mboDebounceTimer);

            function getUnreadInfo() {
                var nodes = document.querySelectorAll('.folder-node');
                var count = 0;
                for (var i = 0; i < nodes.length; i++) {
                    var text = nodes[i].textContent || '';
                    if (text.indexOf('Posteingang') !== -1 || text.indexOf('Inbox') !== -1) {
                        var counter = nodes[i].querySelector('.folder-counter');
                        if (counter) count = parseInt(counter.textContent, 10) || 0;
                        break;
                    }
                }
                // Extract newest unread email's subject and sender from the mail list
                var newest = document.querySelector('.list-item.unread');
                var subject = '';
                var from = '';
                if (newest) {
                    var subEl = newest.querySelector('.subject');
                    var fromEl = newest.querySelector('.from');
                    if (subEl) subject = subEl.textContent.trim();
                    if (fromEl) from = fromEl.textContent.trim();
                }
                window.webkit.messageHandlers.mbomail.postMessage({
                    type: 'unreadCount',
                    count: count,
                    subject: subject,
                    from: from
                });
            }

            // Debounced wrapper: waits for DOM mutations to settle before reading.
            // Prevents rapid-fire postMessage calls when multiple emails arrive at once.
            function debouncedGetUnreadInfo() {
                if (window._mboDebounceTimer) clearTimeout(window._mboDebounceTimer);
                window._mboDebounceTimer = setTimeout(function() {
                    window._mboDebounceTimer = null;
                    getUnreadInfo();
                }, 1500);
            }

            setTimeout(getUnreadInfo, 2000);

            var folderTree = document.querySelector('.tree-container, .folder-tree');
            if (folderTree) {
                window._mboUnreadObserver = new MutationObserver(function() { debouncedGetUnreadInfo(); });
                window._mboUnreadObserver.observe(folderTree, { childList: true, subtree: true, characterData: true });
            }

            window._mboUnreadInterval = setInterval(getUnreadInfo, 30000);
        })();
        """

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.websiteDataStore = .default()
        config.processPool = Self.sharedProcessPool

        let controller = WKUserContentController()
        config.userContentController = controller
        self.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true

        // Set custom User-Agent
        wv.evaluateJavaScript("navigator.userAgent") { result, _ in
            if let ua = result as? String {
                wv.customUserAgent = ua + " MBOMail/1.0"
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
                ContentBlocker.shared.apply(to: controller)
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
        let composeScript = WKUserScript(
            source: Self.composeInterceptJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(hoverScript)
        userContentController.addUserScript(unreadScript)
        userContentController.addUserScript(composeScript)
    }

    // MARK: - Compose Flag

    func syncComposeFlag(_ enabled: Bool) {
        webView.evaluateJavaScript("window._mboComposeInSeparateWindow = \(enabled)")
    }

    /// Open compose via window.open() so the new window inherits sessionStorage.
    /// Triggers createWebViewWith which wraps the WKWebView in a compose NSWindow.
    func openComposeViaWindowOpen(parameters: [String: String] = [:]) {
        var fragment = "#!!&app=io.ox/mail&folder=default0/INBOX&action=compose"
        for (key, value) in parameters {
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            fragment += "&\(key)=\(encoded)"
        }
        let composeURL = "https://app.mailbox.org/appsuite/\(fragment)"
        let escapedURL = composeURL.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("window.open('\(escapedURL)')")
    }

    // MARK: - Native Unread Poll Timer

    /// JS snippet that reads the unread count from the DOM and posts it back to Swift.
    /// Called from a Swift Timer so it fires even when the window is minimized
    /// (WKWebView throttles its own setInterval when not visible).
    private static let unreadPollSnippet = """
        (function() {
            var nodes = document.querySelectorAll('.folder-node');
            var count = 0;
            for (var i = 0; i < nodes.length; i++) {
                var text = nodes[i].textContent || '';
                if (text.indexOf('Posteingang') !== -1 || text.indexOf('Inbox') !== -1) {
                    var counter = nodes[i].querySelector('.folder-counter');
                    if (counter) count = parseInt(counter.textContent, 10) || 0;
                    break;
                }
            }
            var newest = document.querySelector('.list-item.unread');
            var subject = '';
            var from = '';
            if (newest) {
                var subEl = newest.querySelector('.subject');
                var fromEl = newest.querySelector('.from');
                if (subEl) subject = subEl.textContent.trim();
                if (fromEl) from = fromEl.textContent.trim();
            }
            window.webkit.messageHandlers.mbomail.postMessage({ type: 'unreadCount', count: count, subject: subject, from: from });
        })();
        """

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

    private func showPrintWindow(html: String) {
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

        printWV.loadHTMLString(html, baseURL: URL(string: "https://app.mailbox.org"))
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
