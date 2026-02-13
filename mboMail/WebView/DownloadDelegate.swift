import WebKit
import AppKit

@MainActor
final class DownloadDelegate: NSObject, WKDownloadDelegate {

    private var suggestedFilename: String?

    nonisolated func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        await MainActor.run {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = suggestedFilename
            panel.canCreateDirectories = true

            guard panel.runModal() == .OK else { return nil }
            return panel.url
        }
    }

    nonisolated func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Download Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    nonisolated func downloadDidFinish(_ download: WKDownload) {
        // Download completed successfully
    }
}
