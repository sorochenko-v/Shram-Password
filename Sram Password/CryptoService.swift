// CryptoService.swift

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
    private let infoData = Data("SramVault".utf8)

    func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        var passwordData = Data(password.utf8)
        defer { passwordData.resetBytes(in: 0..<passwordData.count) }
        let ikm = SymmetricKey(data: passwordData)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm,
            salt: salt,
            info: infoData,
            outputByteCount: 32
        )
    }

    func encrypt(vault: Vault, using key: SymmetricKey, salt: Data) throws -> Data {
        let plain = try JSONEncoder().encode(vault)
        let sealedBox = try AES.GCM.seal(plain, using: key)
        guard let combined = sealedBox.combined else { throw CryptoError.encryptionFailed }
        var result = salt
        result.append(combined)
        return result
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
