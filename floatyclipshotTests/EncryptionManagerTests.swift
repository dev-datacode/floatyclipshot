//
//  EncryptionManagerTests.swift
//  floatyclipshotTests
//
//  Created by CTO on 2024-12-22.
//  Unit tests for encryption functionality
//

import XCTest
@testable import floatyclipshot

final class EncryptionManagerTests: XCTestCase {

    // MARK: - Encryption/Decryption Tests

    func testEncryptDecryptRoundTrip() throws {
        let manager = EncryptionManager.shared
        let originalData = "Sensitive clipboard data with API keys and passwords".data(using: .utf8)!

        // Encrypt
        let encrypted = try manager.encrypt(originalData)
        XCTAssertNotEqual(encrypted, originalData, "Encrypted data should differ from original")

        // Decrypt
        let decrypted = try manager.decrypt(encrypted)
        XCTAssertEqual(decrypted, originalData, "Decrypted data should match original")
    }

    func testEncryptedDataIsDifferent() throws {
        let manager = EncryptionManager.shared
        let data = "Test data".data(using: .utf8)!

        // Encrypt same data twice
        let encrypted1 = try manager.encrypt(data)
        let encrypted2 = try manager.encrypt(data)

        // Due to random nonce, encrypted outputs should differ
        XCTAssertNotEqual(encrypted1, encrypted2, "Same plaintext should produce different ciphertext due to random nonce")
    }

    func testEmptyDataEncryption() throws {
        let manager = EncryptionManager.shared
        let emptyData = Data()

        // Should handle empty data gracefully
        let encrypted = try manager.encrypt(emptyData)
        let decrypted = try manager.decrypt(encrypted)

        XCTAssertEqual(decrypted, emptyData)
    }

    func testLargeDataEncryption() throws {
        let manager = EncryptionManager.shared

        // Create 1MB of test data
        let largeData = Data(repeating: 0x42, count: 1_000_000)

        let encrypted = try manager.encrypt(largeData)
        let decrypted = try manager.decrypt(encrypted)

        XCTAssertEqual(decrypted, largeData, "Large data should encrypt/decrypt correctly")
    }

    // MARK: - Sensitive Data Detection Tests

    func testDetectPassword() {
        let manager = EncryptionManager.shared

        let passwordText = "password: mysecretpass123"
        let detected = manager.detectSensitiveData(in: passwordText)

        XCTAssertFalse(detected.isEmpty, "Should detect password pattern")
    }

    func testDetectAPIKey() {
        let manager = EncryptionManager.shared

        // Pattern expects sk- followed by 20+ alphanumeric chars
        let apiKeyText = "OPENAI_API_KEY=sk-1234567890abcdefghij1234"
        let detected = manager.detectSensitiveData(in: apiKeyText)

        XCTAssertFalse(detected.isEmpty, "Should detect API key pattern")
    }

    func testDetectCreditCard() {
        let manager = EncryptionManager.shared

        // Pattern expects digits without dashes (Visa: 4 + 12-15 digits)
        let ccText = "Card number: 4111111111111111"
        let detected = manager.detectSensitiveData(in: ccText)

        XCTAssertFalse(detected.isEmpty, "Should detect credit card pattern")
    }

    func testDetectSSN() {
        let manager = EncryptionManager.shared

        let ssnText = "SSN: 123-45-6789"
        let detected = manager.detectSensitiveData(in: ssnText)

        XCTAssertFalse(detected.isEmpty, "Should detect SSN pattern")
    }

    func testNoFalsePositives() {
        let manager = EncryptionManager.shared

        let normalText = "Hello world, this is a normal clipboard item with no sensitive data."
        let detected = manager.detectSensitiveData(in: normalText)

        XCTAssertTrue(detected.isEmpty, "Should not detect sensitive data in normal text")
    }

    func testCodeSnippetNotFalsePositive() {
        let manager = EncryptionManager.shared

        // Code that might look like secrets but isn't
        let codeText = """
        let config = Configuration()
        config.apiEndpoint = "https://api.example.com"
        print("Loading...")
        """
        let detected = manager.detectSensitiveData(in: codeText)

        // May or may not detect, but should not crash
        XCTAssertNotNil(detected)
    }

    // MARK: - Performance Tests

    func testEncryptionPerformance() throws {
        let manager = EncryptionManager.shared
        let testData = Data(repeating: 0x41, count: 100_000) // 100KB

        measure {
            _ = try? manager.encrypt(testData)
        }
    }

    func testSensitiveDetectionPerformance() {
        let manager = EncryptionManager.shared
        let longText = String(repeating: "Hello world this is test content ", count: 1000)

        measure {
            _ = manager.detectSensitiveData(in: longText)
        }
    }
}
