//  VaultViewModel.swift

import Foundation
import CryptoKit
import Observation

@Observable
final class VaultViewModel {
    var entries: [PasswordEntry] = []
    var isUnlocked = false
    
    private var encryptionKey: SymmetricKey?
    private var salt: Data?
    private let cryptoService = CryptoService()
    private let storageService = StorageService()
    
    @MainActor
    func unlockVault(masterPassword: String) async throws {
        let encryptedData: Data
        do {
            encryptedData = try await storageService.loadEncryptedVault()
        } catch StorageError.fileNotFound {
            // First launch: create new vault
            let salt = generateSalt()
            let key = try await cryptoService.deriveKey(from: masterPassword, salt: salt)
            let vault = Vault()
            let encrypted = try await cryptoService.encrypt(vault: vault, using: key, salt: salt)
            try await storageService.saveEncryptedVault(data: encrypted)
            try? await storageService.storeKeyMaterial(key: key, salt: salt)
            self.salt = salt
            self.encryptionKey = key
            entries = []
            isUnlocked = true
            return
        }
        
        // Normal unlock flow
        guard encryptedData.count > 16 else { throw CryptoError.decryptionFailed }
        let salt = encryptedData.prefix(16)
        let key = try await cryptoService.deriveKey(from: masterPassword, salt: salt)
        do {
            let vault = try await cryptoService.decrypt(data: encryptedData, using: key)
            self.salt = salt
            self.encryptionKey = key
            entries = vault.entries
            isUnlocked = true
            try? await storageService.storeKeyMaterial(key: key, salt: salt)
        } catch CryptoError.invalidPassword {
            throw CryptoError.invalidPassword
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
    
    @MainActor
    func unlockWithBiometrics() async throws {
        let material = try await storageService.retrieveKeyMaterial()
        let key = SymmetricKey(data: material.key)
        let encryptedData = try await storageService.loadEncryptedVault()
        let vault = try await cryptoService.decrypt(data: encryptedData, using: key)
        entries = vault.entries
        encryptionKey = key
        salt = material.salt
        isUnlocked = true
    }
    
    @MainActor
    func lock() {
        entries = []
        encryptionKey = nil
        salt = nil
        isUnlocked = false
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
              let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        try await persistVault(key: key, salt: salt)
    }
    
    @MainActor
    func deleteEntry(_ entry: PasswordEntry) async throws {
        guard isUnlocked, let key = encryptionKey, let salt else { return }
        entries.removeAll { $0.id == entry.id }
        try await persistVault(key: key, salt: salt)
    }
    
    private func persistVault(key: SymmetricKey, salt: Data) async throws {
        let vault = Vault(entries: entries)
        let encrypted = try await cryptoService.encrypt(vault: vault, using: key, salt: salt)
        try await storageService.saveEncryptedVault(data: encrypted)
    }
    
    private func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
        return Data(bytes)
    }
}
