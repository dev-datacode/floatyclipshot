//
//  WindowPairing.swift
//  floatyclipshot
//
//  Universal window-to-window pairing for any workflow
//  Supports: Terminal→Simulator, Claude→Browser, Slack→App, etc.
//

import Foundation

/// How to paste the screenshot to the destination window
enum PasteMode: String, Codable, CaseIterable {
    case filePath       // Paste file path (terminals, IDEs, text editors)
    case image          // Paste image directly (chat apps, browsers, design tools)
    case auto           // Auto-detect based on destination app category

    var displayName: String {
        switch self {
        case .filePath: return "File Path"
        case .image: return "Image"
        case .auto: return "Auto"
        }
    }

    var description: String {
        switch self {
        case .filePath: return "Paste screenshot file path (best for terminals & IDEs)"
        case .image: return "Paste image directly (best for chat apps & browsers)"
        case .auto: return "Auto-detect based on target app"
        }
    }
}

/// Represents a pairing between any two windows:
/// - Source Window: Where to PASTE the screenshot (e.g., Terminal, Claude, Slack)
/// - Capture Target: What to CAPTURE (e.g., Simulator, Browser, any app window)
struct WindowPairing: Identifiable, Codable, Equatable {
    let id: UUID

    // SOURCE: Where to PASTE (destination for the screenshot)
    var sourceOwnerName: String          // App name (e.g., "Terminal", "Claude", "Slack")
    var sourceTitlePattern: String       // Window title pattern (e.g., "floatyshot", "Chat")
    var sourceBundleId: String?          // Optional bundle ID for precision

    // CAPTURE: What to CAPTURE (the screenshot target)
    var captureOwnerName: String         // App name (e.g., "Simulator", "Safari", "Figma")
    var captureTitlePattern: String      // Window title pattern (e.g., "iPhone 15 Pro", "localhost")
    var captureBundleId: String?         // Optional bundle ID for precision

    // HOW to paste
    var pasteMode: PasteMode

    // Metadata
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
    var useCount: Int

    init(
        id: UUID = UUID(),
        sourceOwnerName: String,
        sourceTitlePattern: String,
        sourceBundleId: String? = nil,
        captureOwnerName: String,
        captureTitlePattern: String,
        captureBundleId: String? = nil,
        pasteMode: PasteMode = .auto
    ) {
        self.id = id
        self.sourceOwnerName = sourceOwnerName
        self.sourceTitlePattern = sourceTitlePattern
        self.sourceBundleId = sourceBundleId
        self.captureOwnerName = captureOwnerName
        self.captureTitlePattern = captureTitlePattern
        self.captureBundleId = captureBundleId
        self.pasteMode = pasteMode
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastUsedAt = nil
        self.useCount = 0
    }

    // MARK: - Migration from TerminalPairing

    /// Create from legacy TerminalPairing
    init(from legacy: TerminalPairing) {
        self.id = legacy.id
        self.sourceOwnerName = legacy.terminalOwnerName
        self.sourceTitlePattern = legacy.terminalTitlePattern
        self.sourceBundleId = nil
        self.captureOwnerName = legacy.targetOwnerName
        self.captureTitlePattern = legacy.targetTitlePattern
        self.captureBundleId = nil
        self.pasteMode = .auto  // Legacy was always file path for terminals
        self.createdAt = legacy.createdAt
        self.updatedAt = legacy.updatedAt
        self.lastUsedAt = nil
        self.useCount = 0
    }

    // MARK: - Matching

    /// Check if this pairing matches a given source window
    func matchesSource(_ window: WindowInfo) -> Bool {
        // Must match owner name (app name)
        guard window.ownerName == sourceOwnerName else { return false }

        // Match window name pattern (case-insensitive contains)
        if sourceTitlePattern.isEmpty {
            // Empty pattern matches all windows from this app
            return true
        }

        return window.name.localizedCaseInsensitiveContains(sourceTitlePattern)
    }

    /// Find the capture target window from a list of available windows
    func findCaptureTarget(from windows: [WindowInfo]) -> WindowInfo? {
        return windows.first { window in
            // Must match owner name
            guard window.ownerName == captureOwnerName else { return false }

            // Match window name pattern
            if captureTitlePattern.isEmpty {
                return true
            }

            return window.name.localizedCaseInsensitiveContains(captureTitlePattern)
        }
    }

    /// Unique key for source lookup
    var sourceKey: String {
        "\(sourceOwnerName)|\(sourceTitlePattern)"
    }

    // MARK: - Display

    /// Display name for the pairing
    var displayName: String {
        let sourceDisplay = sourceTitlePattern.isEmpty ? sourceOwnerName : "\(sourceOwnerName): \(sourceTitlePattern)"
        let captureDisplay = captureTitlePattern.isEmpty ? captureOwnerName : "\(captureOwnerName): \(captureTitlePattern)"
        return "\(sourceDisplay) → \(captureDisplay)"
    }

    /// Short display name for the source side
    var sourceDisplayName: String {
        sourceTitlePattern.isEmpty ? sourceOwnerName : sourceTitlePattern
    }

    /// Short display name for the capture target side
    var captureDisplayName: String {
        captureTitlePattern.isEmpty ? captureOwnerName : captureTitlePattern
    }

    // MARK: - Mutation

    mutating func update(
        sourceTitlePattern: String? = nil,
        captureOwnerName: String? = nil,
        captureTitlePattern: String? = nil,
        pasteMode: PasteMode? = nil
    ) {
        if let pattern = sourceTitlePattern { self.sourceTitlePattern = pattern }
        if let owner = captureOwnerName { self.captureOwnerName = owner }
        if let pattern = captureTitlePattern { self.captureTitlePattern = pattern }
        if let mode = pasteMode { self.pasteMode = mode }
        self.updatedAt = Date()
    }

    mutating func recordUsage() {
        self.lastUsedAt = Date()
        self.useCount += 1
        self.updatedAt = Date()
    }
}

// MARK: - Backwards Compatibility Aliases

/// Type alias for backwards compatibility
typealias TerminalToWindowPairing = WindowPairing
