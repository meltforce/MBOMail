import SwiftUI
import WebKit

struct MainWindow: View {

    @State private var webViewStore = WebViewStore()
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(AppSettings.self) private var appSettings

    @State private var isLoading = true
    @State private var error: Error?
    @State private var isSessionExpired = false
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var wasDisconnected = false

    private let downloadDelegate = DownloadDelegate()

    var body: some View {
        ZStack {
            WebViewContainer(
                isLoading: $isLoading,
                error: $error,
                isSessionExpired: $isSessionExpired,
                downloadDelegate: downloadDelegate,
                webViewStore: webViewStore
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

            if isSearching {
                VStack {
                    HStack {
                        Spacer()
                        findBar
                    }
                    Spacer()
                }
            }
        }
        .toolbar {
            toolbarContent
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(WindowAccessor())
        .onReceive(NotificationCenter.default.publisher(for: .toggleFind)) { _ in
            isSearching.toggle()
            if !isSearching {
                searchText = ""
                clearFind()
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
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { webViewStore.goBack() }) {
                Image(systemName: "chevron.left")
            }
            .help("Back")

            Button(action: { webViewStore.goForward() }) {
                Image(systemName: "chevron.right")
            }
            .help("Forward")
        }

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

    // MARK: - Find Bar

    private var findBar: some View {
        HStack(spacing: 8) {
            TextField("Find in page...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit {
                    performFind()
                }

            Button(action: performFind) {
                Image(systemName: "magnifyingglass")
            }

            Button(action: {
                isSearching = false
                searchText = ""
                clearFind()
            }) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(8)
    }

    private func performFind() {
        guard !searchText.isEmpty else { return }
        let escaped = searchText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        webViewStore.webView.evaluateJavaScript("window.find('\(escaped)')")
    }

    private func clearFind() {
        webViewStore.webView.evaluateJavaScript("window.getSelection().removeAllRanges()")
    }
}

// MARK: - Window Frame Autosave

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName("MainWindow")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
