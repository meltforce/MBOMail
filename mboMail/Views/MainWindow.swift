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
    @State private var resolvedLink = ""

    private let downloadDelegate = DownloadDelegate()

    var body: some View {
        mainContent
            .frame(minWidth: 800, minHeight: 600)
            .background(WindowAccessor())
            .modifier(ZoomHandlers(webViewStore: webViewStore, appSettings: appSettings))
            .modifier(ActionHandlers(webViewStore: webViewStore, appSettings: appSettings))
            .modifier(SettingsHandlers(webViewStore: webViewStore, appSettings: appSettings))
            .onAppear {
                _ = ZoomKeyMonitor.shared
                NewTabAction.shared.register { [openWindow] in
                    openWindow(id: "main")
                }
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
            .onOpenURL { url in
                if url.scheme == "mailto" {
                    let params = MailtoHandler.parse(url)
                    webViewStore.navigateToCompose(parameters: params)
                }
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
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

            hoverStatusBar
        }
    }

    // MARK: - Hover Status Bar

    @ViewBuilder
    private var hoverStatusBar: some View {
        if !hoveredLink.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(hoveredLink)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !resolvedLink.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(resolvedLink)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
            .padding(4)
            .task(id: hoveredLink) {
                resolvedLink = ""
                guard URLResolver.isShortened(hoveredLink) else { return }
                let linkToResolve = hoveredLink
                if let resolved = await URLResolver.shared.resolve(linkToResolve),
                   hoveredLink == linkToResolve {
                    resolvedLink = resolved
                }
            }
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

// MARK: - Notification Handlers (split into two modifiers to stay within type-checker limits)

private struct ZoomHandlers: ViewModifier {
    let webViewStore: WebViewStore
    let appSettings: AppSettings

    func body(content: Content) -> some View {
        content
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
    }
}

private struct ActionHandlers: ViewModifier {
    let webViewStore: WebViewStore
    let appSettings: AppSettings

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .focusOXSearch)) { _ in
                webViewStore.webView.evaluateJavaScript("""
                    (function() {
                        var searchField = document.querySelector('.search-field input, [data-ref="io.ox/mail/search"] input, input[placeholder*="uch"], input[placeholder*="earch"]');
                        if (searchField) { searchField.focus(); searchField.click(); }
                    })()
                """)
            }
            .onReceive(NotificationCenter.default.publisher(for: .copyMailLink)) { _ in
                webViewStore.copyMessageLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .printMail)) { _ in
                webViewStore.printPage()
            }
            .onReceive(NotificationCenter.default.publisher(for: .reloadPage)) { _ in
                webViewStore.reload()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                if appSettings.autoHideOnFocusLoss {
                    NSApp.hide(nil)
                }
            }
    }
}

// MARK: - Settings Change Handlers

private struct SettingsHandlers: ViewModifier {
    let webViewStore: WebViewStore
    let appSettings: AppSettings

    func body(content: Content) -> some View {
        content
            .onChange(of: appSettings.trackerBlockingEnabled) { _, enabled in
                if enabled {
                    Task {
                        await ContentBlocker.shared.compile()
                        ContentBlocker.shared.apply(to: webViewStore.userContentController)
                        webViewStore.reload()
                    }
                } else {
                    ContentBlocker.shared.remove(from: webViewStore.userContentController)
                    webViewStore.reload()
                }
            }
            .onChange(of: appSettings.customCSS) { _, newCSS in
                webViewStore.injectCustomStyles(css: newCSS)
            }
            .onChange(of: appSettings.customJS) { _, newJS in
                webViewStore.injectCustomScripts(js: newJS)
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
