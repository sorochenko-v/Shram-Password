//  CryptoService.swift

import CryptoKit
import Foundation

enum CryptoError: LocalizedError {
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidPassword

    var errorDescription: String? {
        switch self {
        case .keyDerivationFailed: "Key derivation failed."
        case .encryptionFailed:    "Encryption failed."
        case .decryptionFailed:    "Decryption failed."
        case .invalidPassword:     "Invalid master password."
        }
    }
}

actor CryptoService {

    private let infoData = Data("SramPasswordVault".utf8)

    func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        var passwordData = Data(password.utf8)
        defer { passwordData.resetBytes(in: 0..<passwordData.count) }
        let ikm = SymmetricKey(data: passwordData)
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: infoData, outputByteCount: 32)
    }

    func encrypt(vault: Vault, password: String) throws -> Data {
        var salt = Data(count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, 16, &salt)
        guard status == errSecSuccess else { throw CryptoError.keyDerivationFailed }
        let key = try deriveKey(from: password, salt: salt)
        let plain = try JSONEncoder().encode(vault)
        let sealedBox = try AES.GCM.seal(plain, using: key)
        var result = salt
        result.append(sealedBox.combined!)
        return result
    }

    func encrypt(vault: Vault, using key: SymmetricKey, salt: Data) throws -> Data {
        let plain = try JSONEncoder().encode(vault)
        let sealedBox = try AES.GCM.seal(plain, using: key)
        var result = salt
        result.append(sealedBox.combined!)
        return result
    }

    func decrypt(data: Data, password: String) throws -> Vault {
        guard data.count > 16 else { throw CryptoError.decryptionFailed }
        let salt = data.prefix(16)
        let boxData = data.suffix(from: 16)
        let key = try deriveKey(from: password, salt: salt)
        let sealedBox = try AES.GCM.SealedBox(combined: boxData)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        do {
            return try JSONDecoder().decode(Vault.self, from: decrypted)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }

    func decrypt(data: Data, using key: SymmetricKey) throws -> Vault {
        guard data.count > 16 else { throw CryptoError.decryptionFailed }
        let boxData = data.suffix(from: 16)
        let sealedBox = try AES.GCM.SealedBox(combined: boxData)
        let decrypted: Data
        do {
            decrypted = try AES.GCM.open(sealedBox, using: key)
        } catch CryptoKitError.authenticationFailure {
            throw CryptoError.invalidPassword
        }
        do {
            return try JSONDecoder().decode(Vault.self, from: decrypted)
        } catch {
            throw CryptoError.decryptionFailed
        }
    }
}
