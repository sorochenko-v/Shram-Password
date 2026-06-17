//  VaultViewModel.swift

import Foundation
import CryptoKit
import Observation

@Observable
final class VaultViewModel {
    var entries: [PasswordEntry] = []
    var categories: [Category] = []
    var isUnlocked = false

    private var encryptionKey: SymmetricKey?
    private var salt: Data?
    private let cryptoService = CryptoService()
    private let storageService = StorageService()

    var hasVault: Bool {
        guard let url = vaultFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    private var vaultFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("sram_vault.enc")
    }

    @MainActor
    func unlockVault(masterPassword: String) async throws {
        guard let fileURL = vaultFileURL else { throw CryptoError.decryptionFailed }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let encryptedData = try await storageService.loadEncryptedVault()
            guard encryptedData.count > 16 else { throw CryptoError.decryptionFailed }
            let salt = encryptedData.prefix(16)
            let key = try await cryptoService.deriveKey(from: masterPassword, salt: salt)
            let vault = try await cryptoService.decrypt(data: encryptedData, using: key)
            self.salt = salt
            self.encryptionKey = key
            entries = vault.entries
            categories = vault.categories
            isUnlocked = true
            try? await storageService.storeKeyMaterial(key: key, salt: salt)
        } else {
            let salt = await cryptoService.generateSalt()
            let key = try await cryptoService.deriveKey(from: masterPassword, salt: salt)
            let defaultCategories = [
                Category(name: "Personal", colorHex: "#FF9500"),
                Category(name: "Work", colorHex: "#0A84FF")
            ]
            let vault = Vault(entries: [], categories: defaultCategories)
            let encrypted = try await cryptoService.encrypt(vault: vault, using: key, salt: salt)
            try await storageService.saveEncryptedVault(data: encrypted)
            try? await storageService.storeKeyMaterial(key: key, salt: salt)
            self.salt = salt
            self.encryptionKey = key
            entries = []
            categories = defaultCategories
            isUnlocked = true
        }
    }

    @MainActor
    func unlockWithBiometrics() async throws {
        let material = try await storageService.retrieveKeyMaterial()
        let key = SymmetricKey(data: material.key)
        let encryptedData = try await storageService.loadEncryptedVault()
        let vault = try await cryptoService.decrypt(data: encryptedData, using: key)
        entries = vault.entries
        categories = vault.categories
        encryptionKey = key
        salt = material.salt
        isUnlocked = true
    }

    @MainActor
    func lock() {
        entries.removeAll()
        categories.removeAll()
        encryptionKey = nil
        salt = nil
        isUnlocked = false
    }

    @MainActor
    func wipeAllDataAndReset() async {
        lock()
        if let url = vaultFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        try? await storageService.deleteKeyMaterial()
    }

    @MainActor
    func addEntry(_ entry: PasswordEntry) async throws {
        guard isUnlocked, let key = encryptionKey, let salt else { return }
        entries.append(entry)
        try await persistVault(key: key, salt: salt)
    }

    @MainActor
    func updateEntry(_ entry: PasswordEntry) async throws {
        guard isUnlocked, let key = encryptionKey, let salt,
              let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
        try await persistVault(key: key, salt: salt)
    }

    @MainActor
    func deleteEntry(_ entry: PasswordEntry) async throws {
        guard isUnlocked, let key = encryptionKey, let salt else { return }
        entries.removeAll { $0.id == entry.id }
        try await persistVault(key: key, salt: salt)
    }

    @MainActor
    func addCategory(name: String, colorHex: String) async throws {
        guard isUnlocked, let key = encryptionKey, let salt else { return }
        let newCategory = Category(name: name, colorHex: colorHex)
        categories.append(newCategory)
        try await persistVault(key: key, salt: salt)
    }

    @MainActor
    func deleteCategory(_ category: Category) async throws {
        guard isUnlocked, let key = encryptionKey, let salt else { return }
        categories.removeAll { $0.id == category.id }
        for i in entries.indices {
            if entries[i].categoryId == category.id {
                entries[i].categoryId = nil
            }
        }
        try await persistVault(key: key, salt: salt)
    }

    private func persistVault(key: SymmetricKey, salt: Data) async throws {
        let vault = Vault(entries: entries, categories: categories)
        let encrypted = try await cryptoService.encrypt(vault: vault, using: key, salt: salt)
        try await storageService.saveEncryptedVault(data: encrypted)
    }
}
