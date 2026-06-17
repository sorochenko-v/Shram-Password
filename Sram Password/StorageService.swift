import Foundation
import CryptoKit
import LocalAuthentication
import Security

enum StorageError: LocalizedError {
    case documentsNotFound
    case fileNotFound
    case accessControlFailed
    case keychainSaveFailed(OSStatus)
    case keychainRetrieveFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case userCanceled
    case authenticationFailed
    case noKeyMaterial

    var errorDescription: String? {
        switch self {
        case .documentsNotFound: "Documents directory not found."
        case .fileNotFound:      "Vault file not found."
        case .accessControlFailed: "Access control creation failed."
        case .keychainSaveFailed(let s): "Keychain save error: \(s)"
        case .keychainRetrieveFailed(let s): "Keychain retrieval error: \(s)"
        case .keychainDeleteFailed(let s): "Keychain delete error: \(s)"
        case .userCanceled:       "Authentication cancelled."
        case .authenticationFailed: "Biometric authentication failed."
        case .noKeyMaterial:      "No stored key material."
        }
    }
}

struct KeyMaterial: Codable {
    let key: Data
    let salt: Data
}

actor StorageService {
    private let vaultFileName = "sram_vault.enc"
    private let service = "com.sram.password"
    private let keyAccount = "keyMaterial"

    func vaultFileURL() throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StorageError.documentsNotFound
        }
        return docs.appendingPathComponent(vaultFileName)
    }

    func saveEncryptedVault(data: Data) throws {
        var url = try vaultFileURL()
        try data.write(to: url, options: .atomic)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
    }

    func loadEncryptedVault() throws -> Data {
        let url = try vaultFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StorageError.fileNotFound
        }
        return try Data(contentsOf: url)
    }

    func storeKeyMaterial(key: SymmetricKey, salt: Data) async throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let material = KeyMaterial(key: keyData, salt: salt)
        let encoded = try JSONEncoder().encode(material)

        try? deleteKeyMaterial()
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil
        ) else {
            throw StorageError.accessControlFailed
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount,
            kSecValueData as String: encoded,
            kSecAttrAccessControl as String: accessControl
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError.keychainSaveFailed(status)
        }
    }

    func retrieveKeyMaterial() async throws -> KeyMaterial {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                let context = LAContext()
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.service,
                    kSecAttrAccount as String: self.keyAccount,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                    kSecUseAuthenticationContext as String: context,
                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow
                ]
                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                if status == errSecSuccess, let data = item as? Data {
                    do {
                        let material = try JSONDecoder().decode(KeyMaterial.self, from: data)
                        continuation.resume(returning: material)
                    } catch {
                        continuation.resume(throwing: StorageError.noKeyMaterial)
                    }
                } else if status == errSecUserCanceled {
                    continuation.resume(throwing: StorageError.userCanceled)
                } else if status == errSecAuthFailed {
                    continuation.resume(throwing: StorageError.authenticationFailed)
                } else {
                    continuation.resume(throwing: StorageError.keychainRetrieveFailed(status))
                }
            }
        }
    }

    func deleteKeyMaterial() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.keychainDeleteFailed(status)
        }
    }
}
