//
//  TerminalPairing.swift
//  floatyclipshot
//
//  Terminal-to-target window pairing for multi-desktop workflow
//

import Foundation

/// Represents a pairing between a terminal window and a target capture window
/// When Cmd+Shift+B is pressed in the terminal, the paired target window is captured
struct TerminalPairing: Identifiable, Codable, Equatable {
    let id: UUID

    // Terminal identification (source window)
    var terminalOwnerName: String        // App name (e.g., "Terminal", "iTerm2", "Cursor")
    var terminalTitlePattern: String     // Window title pattern (e.g., "floatyshot", "my-project")

    // Target window identification (window to capture)
    var targetOwnerName: String          // App name (e.g., "Simulator", "Safari", "Chrome")
    var targetTitlePattern: String       // Window title pattern (e.g., "iPhone 15 Pro", "localhost:3000")

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        terminalOwnerName: String,
        terminalTitlePattern: String,
        targetOwnerName: String,
        targetTitlePattern: String
    ) {
        self.id = id
        self.terminalOwnerName = terminalOwnerName
        self.terminalTitlePattern = terminalTitlePattern
        self.targetOwnerName = targetOwnerName
        self.targetTitlePattern = targetTitlePattern
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Check if this pairing matches a given terminal window
    func matchesTerminal(_ window: WindowInfo) -> Bool {
        // Must match owner name (app name)
        guard window.ownerName == terminalOwnerName else { return false }

        // Match window name pattern (case-insensitive contains)
        if terminalTitlePattern.isEmpty {
            // Empty pattern matches all windows from this terminal app
            return true
        }

        return window.name.localizedCaseInsensitiveContains(terminalTitlePattern)
    }

    /// Find the target window from a list of available windows
    func findTargetWindow(from windows: [WindowInfo]) -> WindowInfo? {
        return windows.first { window in
            // Must match owner name
            guard window.ownerName == targetOwnerName else { return false }

            // Match window name pattern
            if targetTitlePattern.isEmpty {
                return true
            }

            return window.name.localizedCaseInsensitiveContains(targetTitlePattern)
        }
    }

    /// Unique key for terminal lookup
    var terminalKey: String {
        "\(terminalOwnerName)|\(terminalTitlePattern)"
    }

    /// Display name for the pairing
    var displayName: String {
        let terminalDisplay = terminalTitlePattern.isEmpty ? terminalOwnerName : "\(terminalOwnerName): \(terminalTitlePattern)"
        let targetDisplay = targetTitlePattern.isEmpty ? targetOwnerName : "\(targetOwnerName): \(targetTitlePattern)"
        return "\(terminalDisplay) → \(targetDisplay)"
    }

    /// Short display name for the terminal side
    var terminalDisplayName: String {
        terminalTitlePattern.isEmpty ? terminalOwnerName : terminalTitlePattern
    }

    /// Short display name for the target side
    var targetDisplayName: String {
        targetTitlePattern.isEmpty ? targetOwnerName : targetTitlePattern
    }

    mutating func update(
        terminalTitlePattern: String? = nil,
        targetOwnerName: String? = nil,
        targetTitlePattern: String? = nil
    ) {
        if let pattern = terminalTitlePattern { self.terminalTitlePattern = pattern }
        if let owner = targetOwnerName { self.targetOwnerName = owner }
        if let pattern = targetTitlePattern { self.targetTitlePattern = pattern }
        self.updatedAt = Date()
    }
}
