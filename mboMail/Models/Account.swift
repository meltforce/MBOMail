import SwiftUI

enum AccountColor: String, Codable, CaseIterable, Identifiable {
    case blue, purple, green, orange, red, pink, teal, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: .blue
        case .purple: .purple
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .pink: .pink
        case .teal: .teal
        case .gray: .gray
        }
    }

    var label: String { rawValue.capitalized }
}

struct Account: Codable, Hashable, Identifiable {
    let id: UUID
    var displayName: String
    var colorTag: AccountColor
    var isDefault: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String = "mailbox.org",
        colorTag: AccountColor = .blue,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.colorTag = colorTag
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
}
