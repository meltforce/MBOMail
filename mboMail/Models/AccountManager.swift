import SwiftUI
import WebKit

@Observable
@MainActor
final class AccountManager {

    static let shared = AccountManager()

    private(set) var accounts: [Account] = []
    var unreadCounts: [UUID: Int] = [:]

    var totalUnread: Int {
        unreadCounts.values.reduce(0, +)
    }

    var defaultAccount: Account? {
        accounts.first(where: { $0.isDefault }) ?? accounts.first
    }

    // MARK: - Persistence

    private static let storageKey = "accounts"
    private static let migrationKey = "multiAccountMigrationComplete"

    private init() {
        load()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Account].self, from: data) else {
            return
        }
        accounts = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: - CRUD

    @discardableResult
    func addAccount(displayName: String = "mailbox.org", colorTag: AccountColor = .blue) -> Account {
        let isFirst = accounts.isEmpty
        var account = Account(displayName: displayName, colorTag: colorTag, isDefault: isFirst)
        if isFirst { account = Account(id: account.id, displayName: displayName, colorTag: colorTag, isDefault: true, createdAt: account.createdAt) }
        accounts.append(account)
        save()
        return account
    }

    func removeAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        unreadCounts.removeValue(forKey: account.id)

        // If the removed account was the default, make the first remaining one default
        if account.isDefault, !accounts.isEmpty {
            accounts[0].isDefault = true
        }
        save()
        updateDockBadge()

        // Delete the persistent data store
        Task {
            try? await WKWebsiteDataStore.remove(forIdentifier: account.id)
        }
    }

    func updateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        save()
    }

    func setDefault(_ account: Account) {
        for i in accounts.indices {
            accounts[i].isDefault = (accounts[i].id == account.id)
        }
        save()
    }

    func account(for id: UUID) -> Account? {
        accounts.first(where: { $0.id == id })
    }

    // MARK: - Data Store Factory

    func dataStore(for accountID: UUID) -> WKWebsiteDataStore {
        WKWebsiteDataStore(forIdentifier: accountID)
    }

    // MARK: - Unread Count

    /// Per-account previous unread counts for notification delta tracking
    private var previousUnreadCounts: [UUID: Int] = [:]

    func updateUnreadCount(for accountID: UUID, count: Int, subject: String, from: String, settings: AppSettings) {
        let previousCount = previousUnreadCounts[accountID] ?? -1
        unreadCounts[accountID] = count
        previousUnreadCounts[accountID] = count
        updateDockBadge()
        StatusItemManager.shared.refreshIcon()

        let accountName = account(for: accountID)?.displayName ?? "mailbox.org"
        NotificationManager.shared.handleUnreadCountChange(
            count,
            previousCount: previousCount,
            accountName: accountName,
            subject: subject,
            from: from,
            settings: settings
        )
    }

    private func updateDockBadge() {
        let total = totalUnread
        NSApp.dockTile.badgeLabel = total > 0 ? "\(total)" : nil
    }

    // MARK: - Migration

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.migrationKey) else { return }

        if accounts.isEmpty {
            // Create a default account for existing users
            let account = Account(displayName: "mailbox.org", colorTag: .blue, isDefault: true)
            accounts.append(account)
            save()

            // Copy cookies from the default data store to the new account's store
            let defaultStore = WKWebsiteDataStore.default()
            let newStore = dataStore(for: account.id)

            Task {
                let cookies = await defaultStore.httpCookieStore.allCookies()
                for cookie in cookies {
                    await newStore.httpCookieStore.setCookie(cookie)
                }
                UserDefaults.standard.set(true, forKey: Self.migrationKey)
            }
        } else {
            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        }
    }
}
