import Foundation
import Combine
import Sparkle

@MainActor
final class UpdateSettingsViewModel: ObservableObject {
    nonisolated let objectWillChange = PassthroughSubject<Void, Never>()

    private let updater: SPUUpdater
    private var cancellables: Set<AnyCancellable> = []

    var automaticallyChecks: Bool {
        get { updater.automaticallyChecksForUpdates }
        set {
            updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    var automaticallyDownloads: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set {
            updater.automaticallyDownloadsUpdates = newValue
            objectWillChange.send()
        }
    }

    /// Update check interval in seconds.
    var checkInterval: TimeInterval {
        get { updater.updateCheckInterval }
        set {
            updater.updateCheckInterval = newValue
            objectWillChange.send()
        }
    }

    var lastCheckDate: Date? {
        updater.lastUpdateCheckDate
    }

    init(updater: SPUUpdater) {
        self.updater = updater

        updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        updater.publisher(for: \.updateCheckInterval)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
