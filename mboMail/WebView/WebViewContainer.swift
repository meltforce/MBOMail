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
        coordinator.onUnreadCount = { count in
            NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
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

    let webView: WKWebView
    let userContentController: WKUserContentController

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

    static let unreadObserverJS = """
        (function() {
            function getUnreadCount() {
                // Find the Inbox folder node by looking for the first .folder-node.show-counter
                // which is always the Inbox (Posteingang), or search all folder-nodes
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
                window.webkit.messageHandlers.mbomail.postMessage({
                    type: 'unreadCount',
                    count: count
                });
            }

            // Initial read (delayed to let DOM settle)
            setTimeout(getUnreadCount, 2000);

            // Observe changes in the folder tree
            var folderTree = document.querySelector('.tree-container, .folder-tree');
            if (folderTree) {
                var observer = new MutationObserver(function() { getUnreadCount(); });
                observer.observe(folderTree, { childList: true, subtree: true, characterData: true });
            }

            // Also poll periodically as a fallback
            setInterval(getUnreadCount, 30000);
        })();
        """

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.isElementFullscreenEnabled = true
        config.websiteDataStore = .default()

        let controller = WKUserContentController()
        config.userContentController = controller
        self.userContentController = controller

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

        // Add permanent scripts
        addPermanentScripts()
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
