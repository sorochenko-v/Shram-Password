//  Models.swift

import SwiftUI

extension Color {
    static let sramRed = Color(red: 0.55, green: 0, blue: 0)
}

enum EntryType: String, Codable, CaseIterable, Identifiable, Sendable {
    case website = "Website"
    case app = "App"
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
