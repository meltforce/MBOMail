import SwiftUI
import WebKit

struct MainWindow: View {

    @State private var webViewStore = WebViewStore()
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.openWindow) private var openWindow

    @State private var isLoading = true
    @State private var error: Error?
    @State private var isSessionExpired = false
    @State private var wasDisconnected = false
    @State private var hoveredLink = ""

    private let downloadDelegate = DownloadDelegate()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WebViewContainer(
                isLoading: $isLoading,
                error: $error,
                isSessionExpired: $isSessionExpired,
                downloadDelegate: downloadDelegate,
                webViewStore: webViewStore,
                hoveredLink: $hoveredLink
            )

            if isLoading && error == nil && networkMonitor.isConnected {
                loadingOverlay
            }

            if let error = error, networkMonitor.isConnected {
                errorOverlay(error)
            }

            if !networkMonitor.isConnected {
                offlineOverlay
            }

            // Link hover status bar
            if !hoveredLink.isEmpty {
                Text(hoveredLink)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
        .toolbar {
            toolbarContent
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(WindowAccessor())
        .onReceive(NotificationCenter.default.publisher(for: .focusOXSearch)) { _ in
            // Click the OX search field via JS
            webViewStore.webView.evaluateJavaScript("""
                (function() {
                    var searchField = document.querySelector('.search-field input, [data-ref="io.ox/mail/search"] input, input[placeholder*="uch"], input[placeholder*="earch"]');
                    if (searchField) { searchField.focus(); searchField.click(); }
                })()
            """)
        }
        .onAppear {
            _ = ZoomKeyMonitor.shared
            NewTabAction.shared.register { [openWindow] in
                openWindow(id: "main")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in
            let newZoom = min(webViewStore.currentZoom + 0.1, 3.0)
            webViewStore.setZoom(newZoom)
            appSettings.zoomLevel = newZoom
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in
            let newZoom = max(webViewStore.currentZoom - 0.1, 0.5)
            webViewStore.setZoom(newZoom)
            appSettings.zoomLevel = newZoom
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomReset)) { _ in
            webViewStore.setZoom(1.0)
            appSettings.zoomLevel = 1.0
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if isConnected && wasDisconnected {
                error = nil
                webViewStore.reload()
                wasDisconnected = false
            } else if !isConnected {
                wasDisconnected = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyMailLink)) { _ in
            webViewStore.copyMessageLink()
        }
        .onReceive(NotificationCenter.default.publisher(for: .printMail)) { _ in
            webViewStore.printPage()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if appSettings.autoHideOnFocusLoss {
                NSApp.hide(nil)
            }
        }
        .onChange(of: appSettings.customCSS) { _, newCSS in
            webViewStore.injectCustomStyles(css: newCSS)
        }
        .onChange(of: appSettings.customJS) { _, newJS in
            webViewStore.injectCustomScripts(js: newJS)
        }
        .onOpenURL { url in
            if url.scheme == "mailto" {
                let params = MailtoHandler.parse(url)
                webViewStore.navigateToCompose(parameters: params)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: { webViewStore.reload() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload")
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            ProgressView("Loading mailbox.org...")
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
        }
    }

    // MARK: - Error Overlay

    private func errorOverlay(_ error: Error) -> some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Unable to load mailbox.org")
                    .font(.title2)
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                Button("Retry") {
                    self.error = nil
                    webViewStore.loadMailboxOrg()
                }
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }

    // MARK: - Offline Overlay

    private var offlineOverlay: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).opacity(0.9)
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Internet Connection")
                    .font(.title2)
                Text("Waiting for network... The page will reload automatically when connectivity is restored.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
        }
    }
}

// MARK: - Window Configuration

private class WindowConfigView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = self.window else { return }
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "mboMailMainWindow"
        window.setFrameAutosaveName("MainWindow")
    }
}

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowConfigView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
