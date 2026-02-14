import SwiftUI
import Combine
import Sparkle

// Sparkle's SPUUpdater uses KVO/Combine, which requires ObservableObject (not @Observable).
// Opt out of default MainActor isolation since ObservableObject's objectWillChange is nonisolated.
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    nonisolated let objectWillChange = PassthroughSubject<Void, Never>()

    var canCheckForUpdates = false {
        didSet { objectWillChange.send() }
    }

    let updater: SPUUpdater
    private var cancellable: AnyCancellable?

    init(updater: SPUUpdater) {
        self.updater = updater
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.canCheckForUpdates = value
            }
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        self.viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates...") {
            viewModel.updater.checkForUpdates()
        }
        // Don't disable — better to show an error dialog than a greyed-out menu item.
        // Sparkle reports canCheckForUpdates=false until a valid SUPublicEDKey is configured.
    }
}
