//
//  WindowTag.swift
//  floatyclipshot
//
//  Window tagging model for project identification
//

import Foundation
import SwiftUI

/// Apple-style tag colors matching macOS Finder tags
enum TagColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red:      return Color(red: 1.0, green: 0.23, blue: 0.19)
        case .orange:   return Color(red: 1.0, green: 0.58, blue: 0.0)
        case .yellow:   return Color(red: 1.0, green: 0.80, blue: 0.0)
        case .green:    return Color(red: 0.30, green: 0.85, blue: 0.39)
        case .blue:     return Color(red: 0.0, green: 0.48, blue: 1.0)
        case .purple:   return Color(red: 0.69, green: 0.32, blue: 0.87)
        case .gray:     return Color(red: 0.56, green: 0.56, blue: 0.58)
        }
    }

    var nsColor: NSColor {
        switch self {
        case .red:      return NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        case .orange:   return NSColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
        case .yellow:   return NSColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0)
        case .green:    return NSColor(red: 0.30, green: 0.85, blue: 0.39, alpha: 1.0)
        case .blue:     return NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        case .purple:   return NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)
        case .gray:     return NSColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

/// Represents a tag attached to a window for project identification
struct WindowTag: Identifiable, Codable, Equatable {
    let id: UUID
    var projectName: String
    var tagColor: TagColor

    // Window matching criteria (windows change IDs frequently, so we use owner+name pattern)
    var ownerName: String           // App name (e.g., "Xcode", "Visual Studio Code")
    var windowNamePattern: String   // Window title pattern to match

    // Display options
    var showProjectName: Bool
    var position: TagPosition

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        projectName: String,
        tagColor: TagColor,
        ownerName: String,
        windowNamePattern: String,
        showProjectName: Bool = true,
        position: TagPosition = .topLeft
    ) {
        self.id = id
        self.projectName = projectName
        self.tagColor = tagColor
        self.ownerName = ownerName
        self.windowNamePattern = windowNamePattern
        self.showProjectName = showProjectName
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Check if this tag matches a given window
    func matches(window: WindowInfo) -> Bool {
        // Must match owner name (app name)
        guard window.ownerName == ownerName else { return false }

        // Match window name pattern (case-insensitive contains)
        if windowNamePattern.isEmpty {
            // Empty pattern matches all windows from this app
            return true
        }

        return window.name.localizedCaseInsensitiveContains(windowNamePattern)
    }

    /// Create a unique key for window matching
    var matchKey: String {
        "\(ownerName)|\(windowNamePattern)"
    }

    mutating func update(projectName: String? = nil, tagColor: TagColor? = nil, showProjectName: Bool? = nil, position: TagPosition? = nil, windowNamePattern: String? = nil) {
        if let name = projectName { self.projectName = name }
        if let color = tagColor { self.tagColor = color }
        if let show = showProjectName { self.showProjectName = show }
        if let pos = position { self.position = pos }
        if let pattern = windowNamePattern { self.windowNamePattern = pattern }
        self.updatedAt = Date()
    }
}

/// Position of the floating tag relative to the window
enum TagPosition: String, Codable, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft:      return "Top Left"
        case .topRight:     return "Top Right"
        case .bottomLeft:   return "Bottom Left"
        case .bottomRight:  return "Bottom Right"
        }
    }

    var icon: String {
        switch self {
        case .topLeft:      return "arrow.up.left.square"
        case .topRight:     return "arrow.up.right.square"
        case .bottomLeft:   return "arrow.down.left.square"
        case .bottomRight:  return "arrow.down.right.square"
        }
    }
}
