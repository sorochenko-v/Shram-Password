import SwiftUI

// MARK: - Brand Accent
extension Color {
    static let sramRed = Color(red: 0.55, green: 0, blue: 0)
}

// MARK: - Theme
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"
    var id: Self { self }
}

// MARK: - Adaptive Colors (react to current ColorScheme)
extension Color {
    static var sramBackground: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1)
                                               : UIColor(white: 0.93, alpha: 1)
        })
    }
    static var sramSurface: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.15, alpha: 1)
                                               : UIColor.white
        })
    }
    static var sramRowBackground: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1)
                                               : UIColor(white: 0.97, alpha: 1)
        })
    }
    static var sramFieldBackground: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.2, alpha: 1)
                                               : UIColor(white: 0.88, alpha: 1)
        })
    }
    static var sramBorder: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.3, alpha: 1)
                                               : UIColor(white: 0.75, alpha: 1)
        })
    }
    static var sramTextSecondary: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.gray
                                               : UIColor.darkGray
        })
    }
    static var sramLogoColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.white
                                               : UIColor(white: 0.15, alpha: 1)
        })
    }
}

// MARK: - Data Models (Sendable для безпечної конкурентності)
enum EntryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case website = "Website"
    case app     = "App"
    var id: Self { self }
}

struct Category: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
    static func == (lhs: Category, rhs: Category) -> Bool { lhs.id == rhs.id }
}

struct PasswordEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String
    var username: String
    var password: String
    var notes: String
    var website: String
    var type: EntryType = .website
    var categoryId: UUID?
    var createdAt: Date = Date()
    static func == (lhs: PasswordEntry, rhs: PasswordEntry) -> Bool { lhs.id == rhs.id }
}

struct Vault: Codable, Equatable, Sendable {
    var entries: [PasswordEntry] = []
    var categories: [Category] = []
}
