//
//  SettingsManagerTests.swift
//  floatyclipshotTests
//
//  Created by CTO on 2024-12-22.
//  Unit tests for SettingsManager defaults and security settings
//

import XCTest
@testable import floatyclipshot

@MainActor
final class SettingsManagerTests: XCTestCase {

    private var testDefaults: UserDefaults!

    override func setUp() async throws {
        // Use a separate UserDefaults suite for testing
        testDefaults = UserDefaults(suiteName: "com.floatyclipshot.tests")
        testDefaults?.removePersistentDomain(forName: "com.floatyclipshot.tests")
    }

    override func tearDown() async throws {
        testDefaults?.removePersistentDomain(forName: "com.floatyclipshot.tests")
        testDefaults = nil
    }

    // MARK: - Security Default Tests

    func testEncryptionEnabledByDefault() {
        // CRITICAL: Encryption should be ON by default for security
        // This test ensures the production-ready security default is maintained

        let settings = SettingsManager.shared

        // For a fresh install (no stored value), encryption should be enabled
        // Note: This tests the getter logic, not actual fresh install state
        // The getter returns true when no value is stored
        XCTAssertTrue(settings.encryptionEnabled, "Encryption should be enabled by default for security")
    }

    func testAutoDetectSensitiveEnabledByDefault() {
        // Sensitive data detection should be ON by default
        let settings = SettingsManager.shared
        XCTAssertTrue(settings.autoDetectSensitive, "Auto-detect sensitive should be enabled by default")
    }

    func testSensitivePurgeDefaultsTo60Minutes() {
        // Sensitive data should auto-purge after 60 minutes by default
        let settings = SettingsManager.shared
        XCTAssertEqual(settings.sensitivePurgeMinutes, 60, "Sensitive purge should default to 60 minutes")
    }

    func testHotkeysEnabledByDefault() {
        // Both hotkeys should be enabled for new users
        let settings = SettingsManager.shared
        XCTAssertTrue(settings.hotkeyEnabled, "Capture hotkey should be enabled by default")
        XCTAssertTrue(settings.pasteHotkeyEnabled, "Paste hotkey should be enabled by default")
    }

    // MARK: - Storage Limit Tests

    func testStorageLimitDefault() {
        let settings = SettingsManager.shared
        XCTAssertEqual(settings.storageLimit, .limit500MB, "Default storage limit should be 500MB")
    }

    func testStorageLimitDisplayNames() {
        XCTAssertEqual(StorageLimit.limit100MB.displayName, "100 MB")
        XCTAssertEqual(StorageLimit.limit500MB.displayName, "500 MB")
        XCTAssertEqual(StorageLimit.limit1GB.displayName, "1 GB")
        XCTAssertEqual(StorageLimit.unlimited.displayName, "Unlimited")
    }

    func testStorageLimitBytes() {
        XCTAssertEqual(StorageLimit.limit100MB.bytes, 104_857_600)
        XCTAssertEqual(StorageLimit.limit1GB.bytes, 1_073_741_824)
        XCTAssertTrue(StorageLimit.unlimited.isUnlimited)
    }

    func testCalculateTargetSize() {
        let settings = SettingsManager.shared

        // Target size should be 70% of limit
        let target500MB = settings.calculateTargetSize(for: .limit500MB)
        let expected = Int64(Double(StorageLimit.limit500MB.bytes) * 0.7)
        XCTAssertEqual(target500MB, expected)

        // Unlimited should return max
        let targetUnlimited = settings.calculateTargetSize(for: .unlimited)
        XCTAssertEqual(targetUnlimited, Int64.max)
    }

    // MARK: - Sensitive Purge Interval Tests

    func testSensitivePurgeIntervalCases() {
        XCTAssertEqual(SettingsManager.SensitivePurgeInterval.never.rawValue, 0)
        XCTAssertEqual(SettingsManager.SensitivePurgeInterval.hour1.rawValue, 60)
        XCTAssertEqual(SettingsManager.SensitivePurgeInterval.hours24.rawValue, 1440)
    }

    func testSensitivePurgeIntervalDisplayNames() {
        XCTAssertEqual(SettingsManager.SensitivePurgeInterval.never.displayName, "Never")
        XCTAssertEqual(SettingsManager.SensitivePurgeInterval.hour1.displayName, "1 hour")
        XCTAssertEqual(SettingsManager.SensitivePurgeInterval.hours24.displayName, "24 hours")
    }
}
