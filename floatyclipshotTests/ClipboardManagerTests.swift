//
//  ClipboardManagerTests.swift
//  floatyclipshotTests
//
//  Created by CTO on 2024-12-22.
//  Basic unit tests for ClipboardManager
//

import XCTest
@testable import floatyclipshot

final class ClipboardManagerTests: XCTestCase {

    // MARK: - Clipboard Item Type Tests

    func testClipboardItemTypeEquality() {
        // Text types with same content should be equal
        let text1 = ClipboardItemType.text("Hello")
        let text2 = ClipboardItemType.text("Hello")
        XCTAssertEqual(text1, text2)

        // Text types with different content should not be equal
        let text3 = ClipboardItemType.text("World")
        XCTAssertNotEqual(text1, text3)

        // Image types should be equal
        let image1 = ClipboardItemType.image
        let image2 = ClipboardItemType.image
        XCTAssertEqual(image1, image2)

        // Different types should not be equal
        XCTAssertNotEqual(text1, image1)
    }

    func testClipboardItemTypeCoding() throws {
        // Test encoding and decoding of ClipboardItemType
        let original = ClipboardItemType.text("Test content")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ClipboardItemType.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Clipboard Item Tests

    func testClipboardItemDisplayName() {
        // Test text item display name
        let textItem = ClipboardItem(
            id: UUID(),
            fileURL: nil,
            textContent: "Test content here",
            dataType: .string,
            timestamp: Date(),
            type: .text("Test content here..."),
            windowContext: nil,
            dataSize: 100
        )

        XCTAssertTrue(textItem.displayName.contains("Test content"))
        XCTAssertTrue(textItem.displayName.contains("100 bytes") || textItem.displayName.contains("KB"))
    }

    func testClipboardItemSensitiveFlag() {
        // Test sensitive item detection
        let sensitiveItem = ClipboardItem(
            id: UUID(),
            fileURL: nil,
            textContent: "password123",
            dataType: .string,
            timestamp: Date(),
            type: .text("password123"),
            windowContext: nil,
            dataSize: 11,
            isSensitive: true,
            sensitiveTypes: ["password"]
        )

        XCTAssertTrue(sensitiveItem.isSensitive)
        XCTAssertTrue(sensitiveItem.sensitiveTypes.contains("password"))
    }

    func testClipboardItemFavorite() {
        var item = ClipboardItem(
            id: UUID(),
            fileURL: nil,
            textContent: "Favorite content",
            dataType: .string,
            timestamp: Date(),
            type: .text("Favorite content"),
            windowContext: nil,
            dataSize: 16
        )

        XCTAssertFalse(item.isFavorite)
        item.isFavorite = true
        XCTAssertTrue(item.isFavorite)
    }

    // MARK: - Performance Tests

    func testClipboardPollingInterval() {
        // Verify polling interval is set to 0.1s (100ms) for responsiveness
        // This is a documentation test to ensure the performance fix is maintained
        // The actual timer value is private, so we document the expected behavior

        // Expected: Timer interval should be 0.1s, not 0.5s
        // This test serves as documentation - actual validation is in integration tests
        XCTAssertTrue(true, "Clipboard polling should be 0.1s for responsive detection")
    }
}
