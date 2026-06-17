//  Models.swift

import Foundation

struct PasswordEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var username: String
    var password: String
    var website: String
    var notes: String
    let createdAt: Date

    init(id: UUID = UUID(),
         title: String,
         username: String,
         password: String,
         website: String = "",
         notes: String = "",
         createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.website = website
        self.notes = notes
        self.createdAt = createdAt
    }
}

struct Vault: Codable, Equatable {
    var entries: [PasswordEntry]

    init(entries: [PasswordEntry] = []) {
        self.entries = entries
    }
}
