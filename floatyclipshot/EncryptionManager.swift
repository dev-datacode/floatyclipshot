//
//  EncryptionManager.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Provides AES-256-GCM encryption for clipboard history storage.
//  Encryption key is stored securely in macOS Keychain.
//

import Foundation
import CryptoKit
import Security

/// Manages encryption/decryption of sensitive clipboard data
/// Uses AES-256-GCM (authenticated encryption) with Keychain-stored keys
final class EncryptionManager {
    static let shared = EncryptionManager()

    // MARK: - Constants

    private enum Constants {
        static let keychainService = "com.floatyclipshot.encryption"
        static let keychainAccount = "clipboardHistoryKey"
        static let keySize = 32 // 256 bits for AES-256
    }

    // MARK: - Errors

    enum EncryptionError: LocalizedError {
        case keyGenerationFailed
        case keychainAccessFailed(OSStatus)
        case encryptionFailed(Error)
        case decryptionFailed(Error)
        case invalidData
        case keyNotFound

        var errorDescription: String? {
            switch self {
            case .keyGenerationFailed:
                return "Failed to generate encryption key"
            case .keychainAccessFailed(let status):
                return "Keychain access failed with status: \(status)"
            case .encryptionFailed(let error):
                return "Encryption failed: \(error.localizedDescription)"
            case .decryptionFailed(let error):
                return "Decryption failed: \(error.localizedDescription)"
            case .invalidData:
                return "Invalid encrypted data format"
            case .keyNotFound:
                return "Encryption key not found in Keychain"
            }
        }
    }

    // MARK: - Properties

    /// Cached encryption key (loaded from Keychain on first access)
    private var cachedKey: SymmetricKey?

    /// Serial queue for thread-safe key access
    private let keyQueue = DispatchQueue(label: "com.floatyclipshot.encryption.keyQueue")

    // MARK: - Initialization

    private init() {
        // Key is lazily loaded from Keychain on first use
    }

    // MARK: - Public API

    /// Encrypt data using AES-256-GCM
    /// - Parameter data: Plain data to encrypt
    /// - Returns: Encrypted data (nonce + ciphertext + tag)
    /// - Throws: EncryptionError if encryption fails
    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)

            // Combine nonce + ciphertext + tag for storage
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed(NSError(domain: "EncryptionManager", code: -1))
            }

            return combined
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.encryptionFailed(error)
        }
    }

    /// Decrypt data that was encrypted with encrypt()
    /// - Parameter encryptedData: Combined nonce + ciphertext + tag
    /// - Returns: Original plain data
    /// - Throws: EncryptionError if decryption fails
    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateKey()

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.decryptionFailed(error)
        }
    }

    /// Encrypt a string
    /// - Parameter string: Plain string to encrypt
    /// - Returns: Base64-encoded encrypted data
    /// - Throws: EncryptionError if encryption fails
    func encryptString(_ string: String) throws -> String {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        let encrypted = try encrypt(data)
        return encrypted.base64EncodedString()
    }

    /// Decrypt a Base64-encoded encrypted string
    /// - Parameter encryptedString: Base64-encoded encrypted data
    /// - Returns: Original plain string
    /// - Throws: EncryptionError if decryption fails
    func decryptString(_ encryptedString: String) throws -> String {
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            throw EncryptionError.invalidData
        }
        let decrypted = try decrypt(encryptedData)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        return string
    }

    /// Check if encryption is available (key exists or can be created)
    var isEncryptionAvailable: Bool {
        do {
            _ = try getOrCreateKey()
            return true
        } catch {
            print("Encryption not available: \(error)")
            return false
        }
    }

    /// Check if an encryption key already exists in Keychain
    var hasExistingKey: Bool {
        do {
            _ = try loadKeyFromKeychain()
            return true
        } catch {
            return false
        }
    }

    /// Delete the encryption key from Keychain
    /// WARNING: This will make all encrypted data unreadable!
    func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            throw EncryptionError.keychainAccessFailed(status)
        }

        // Clear cached key
        keyQueue.sync {
            cachedKey = nil
        }

        print("Encryption key deleted from Keychain")
    }

    /// Rotate the encryption key (generate new key)
    /// Returns the old key so data can be re-encrypted
    /// - Returns: Tuple of (oldKey, newKey) for re-encryption
    func rotateKey() throws -> (old: SymmetricKey, new: SymmetricKey) {
        let oldKey = try getOrCreateKey()

        // Delete old key
        try deleteKey()

        // Generate new key
        let newKey = try getOrCreateKey()

        return (oldKey, newKey)
    }

    // MARK: - Private Methods

    /// Get existing key from cache/Keychain or create a new one
    private func getOrCreateKey() throws -> SymmetricKey {
        // Check cache first (thread-safe)
        if let cached = keyQueue.sync(execute: { cachedKey }) {
            return cached
        }

        // Try to load from Keychain
        do {
            let key = try loadKeyFromKeychain()
            keyQueue.sync { cachedKey = key }
            return key
        } catch EncryptionError.keyNotFound {
            // Key doesn't exist, create new one
            let newKey = try generateAndStoreKey()
            keyQueue.sync { cachedKey = newKey }
            return newKey
        }
    }

    /// Generate a new encryption key and store in Keychain
    private func generateAndStoreKey() throws -> SymmetricKey {
        // Generate cryptographically secure random key
        let key = SymmetricKey(size: .bits256)

        // Extract key data for Keychain storage
        let keyData = key.withUnsafeBytes { Data($0) }

        // Store in Keychain with strong protection
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            // Require user presence for extra security (optional, can be removed if too intrusive)
            // kSecAttrAccessControl as String: SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .userPresence, nil)!
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            throw EncryptionError.keychainAccessFailed(status)
        }

        print("New encryption key generated and stored in Keychain")
        return key
    }

    /// Load encryption key from Keychain
    private func loadKeyFromKeychain() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            throw EncryptionError.keyNotFound
        }

        if status != errSecSuccess {
            throw EncryptionError.keychainAccessFailed(status)
        }

        guard let keyData = result as? Data, keyData.count == Constants.keySize else {
            throw EncryptionError.invalidData
        }

        return SymmetricKey(data: keyData)
    }
}

// MARK: - Encrypted Data Container

/// Container for encrypted data with metadata
struct EncryptedContainer: Codable {
    let version: Int
    let encryptedData: Data
    let createdAt: Date

    static let currentVersion = 1

    init(encryptedData: Data) {
        self.version = Self.currentVersion
        self.encryptedData = encryptedData
        self.createdAt = Date()
    }
}

// MARK: - Sensitive Item Detection

extension EncryptionManager {

    /// Patterns that indicate sensitive content
    private static let sensitivePatterns: [(pattern: String, type: SensitiveDataType)] = [
        // API Keys
        ("sk-[a-zA-Z0-9]{20,}", .apiKey),           // OpenAI
        ("sk_live_[a-zA-Z0-9]{20,}", .apiKey),      // Stripe
        ("sk_test_[a-zA-Z0-9]{20,}", .apiKey),      // Stripe test
        ("AKIA[0-9A-Z]{16}", .apiKey),              // AWS Access Key
        ("ghp_[a-zA-Z0-9]{36}", .apiKey),           // GitHub Personal Access Token
        ("gho_[a-zA-Z0-9]{36}", .apiKey),           // GitHub OAuth
        ("glpat-[a-zA-Z0-9-]{20}", .apiKey),        // GitLab

        // Passwords (common patterns)
        ("password[\"']?\\s*[:=]\\s*[\"']?.{6,}", .password),
        ("passwd[\"']?\\s*[:=]\\s*[\"']?.{6,}", .password),
        ("pwd[\"']?\\s*[:=]\\s*[\"']?.{6,}", .password),

        // Private keys
        ("-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----", .privateKey),
        ("-----BEGIN PGP PRIVATE KEY BLOCK-----", .privateKey),

        // Connection strings
        ("mongodb(\\+srv)?://[^\\s]+", .connectionString),
        ("postgres(ql)?://[^\\s]+", .connectionString),
        ("mysql://[^\\s]+", .connectionString),
        ("redis://[^\\s]+", .connectionString),

        // Tokens
        ("bearer\\s+[a-zA-Z0-9-._~+/]+=*", .token),
        ("token[\"']?\\s*[:=]\\s*[\"']?[a-zA-Z0-9-._]{20,}", .token),

        // Credit cards (basic pattern)
        ("\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\\b", .creditCard),

        // SSN (US)
        ("\\b\\d{3}-\\d{2}-\\d{4}\\b", .ssn),
    ]

    enum SensitiveDataType: String, Codable {
        case apiKey = "API Key"
        case password = "Password"
        case privateKey = "Private Key"
        case connectionString = "Connection String"
        case token = "Token"
        case creditCard = "Credit Card"
        case ssn = "SSN"
        case unknown = "Sensitive Data"
    }

    /// Detect if text contains sensitive data
    /// - Parameter text: Text to analyze
    /// - Returns: Array of detected sensitive data types
    func detectSensitiveData(in text: String) -> [SensitiveDataType] {
        var detected: Set<SensitiveDataType> = []

        for (pattern, type) in Self.sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    detected.insert(type)
                }
            }
        }

        return Array(detected)
    }

    /// Check if text likely contains sensitive data
    /// - Parameter text: Text to check
    /// - Returns: True if potentially sensitive
    func isSensitive(_ text: String) -> Bool {
        !detectSensitiveData(in: text).isEmpty
    }
}
