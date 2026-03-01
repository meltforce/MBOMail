import SwiftUI

struct AccountsSettingsTab: View {

    private let accountManager = AccountManager.shared
    @State private var selectedAccount: Account?
    @State private var showDeleteConfirmation = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                List(accountManager.accounts, selection: $selectedAccount) { account in
                    AccountRow(account: account)
                        .tag(account)
                }
                .frame(minHeight: 120)

                HStack {
                    Button {
                        let account = accountManager.addAccount(
                            colorTag: nextColor()
                        )
                        openWindow(id: "mail", value: WindowID(accountID: account.id))
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(selectedAccount == nil || accountManager.accounts.count <= 1)

                    Spacer()
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Accounts")
            } footer: {
                Text("Each account uses an isolated session. Add an account and log in with different credentials.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let selected = selectedAccount,
               let account = accountManager.account(for: selected.id) {
                AccountDetailEditor(account: account)
            }
        }
        .formStyle(.grouped)
        .alert("Remove Account?", isPresented: $showDeleteConfirmation) {
            Button("Remove", role: .destructive) {
                if let account = selectedAccount {
                    selectedAccount = nil
                    accountManager.removeAccount(account)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let account = selectedAccount {
                Text("This will remove \"\(account.displayName)\" and delete all its stored data (cookies, sessions). This cannot be undone.")
            }
        }
    }

    private func nextColor() -> AccountColor {
        let usedColors = Set(accountManager.accounts.map(\.colorTag))
        return AccountColor.allCases.first(where: { !usedColors.contains($0) }) ?? .blue
    }
}

// MARK: - Account Row

private struct AccountRow: View {
    let account: Account

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(account.colorTag.color)
                .frame(width: 10, height: 10)

            Text(account.displayName)

            if account.isDefault {
                Text("Default")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Spacer()

            let unread = AccountManager.shared.unreadCounts[account.id] ?? 0
            if unread > 0 {
                Text("\(unread)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15), in: Capsule())
            }
        }
    }
}

// MARK: - Account Detail Editor

private struct AccountDetailEditor: View {
    let account: Account
    @State private var editedName: String = ""
    @State private var editedColor: AccountColor = .blue

    var body: some View {
        Section("Account Settings") {
            TextField("Display Name", text: $editedName)
                .onSubmit { saveChanges() }

            Picker("Color", selection: $editedColor) {
                ForEach(AccountColor.allCases) { color in
                    HStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 10, height: 10)
                        Text(color.label)
                    }
                    .tag(color)
                }
            }

            Toggle("Default Account", isOn: Binding(
                get: { account.isDefault },
                set: { newValue in
                    if newValue {
                        AccountManager.shared.setDefault(account)
                    }
                }
            ))

            if !account.isDefault {
                Text("The default account receives mailto: links.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { loadAccount() }
        .onChange(of: account.id) { loadAccount() }
        .onChange(of: editedName) { saveChanges() }
        .onChange(of: editedColor) { saveChanges() }
    }

    private func loadAccount() {
        editedName = account.displayName
        editedColor = account.colorTag
    }

    private func saveChanges() {
        var updated = account
        updated.displayName = editedName
        updated.colorTag = editedColor
        AccountManager.shared.updateAccount(updated)
    }
}
