//
//  AppCategories.swift
//  floatyclipshot
//
//  Smart detection of app categories for auto paste mode selection
//  Determines whether to paste as file path or image based on app type
//

import Foundation
import AppKit

/// Categories of apps for smart paste mode detection
enum AppCategory: String, CaseIterable {
    // File path paste (these apps work better with file paths)
    case terminal           // Terminal, iTerm, Warp → file path
    case ide                // VS Code, Cursor, Xcode → file path
    case textEditor         // Sublime, TextEdit, nvim → file path

    // Image paste (these apps work better with images)
    case aiChat             // Claude, ChatGPT, Gemini → image
    case messaging          // Slack, Discord, Teams → image
    case browser            // Safari, Chrome → depends on context
    case documentation      // Notion, Obsidian, Confluence → image
    case ticketing          // Jira, Linear, GitHub Issues → image
    case design             // Figma, Sketch, Preview → image
    case email              // Mail, Outlook, Gmail → image

    // Generic (unknown apps)
    case generic            // Unknown → image (safer default)

    /// Preferred paste mode for this category
    var preferredPasteMode: PasteMode {
        switch self {
        case .terminal, .ide, .textEditor:
            return .filePath
        case .aiChat, .messaging, .documentation, .ticketing, .design, .email:
            return .image
        case .browser:
            return .image  // Most browser contexts prefer image
        case .generic:
            return .image  // Safer default for unknown apps
        }
    }

    /// Human-readable description
    var description: String {
        switch self {
        case .terminal: return "Terminal"
        case .ide: return "IDE"
        case .textEditor: return "Text Editor"
        case .aiChat: return "AI Chat"
        case .messaging: return "Messaging"
        case .browser: return "Browser"
        case .documentation: return "Documentation"
        case .ticketing: return "Issue Tracking"
        case .design: return "Design"
        case .email: return "Email"
        case .generic: return "Other"
        }
    }
}

/// Central registry for app detection and categorization
/// Replaces TerminalApps with more comprehensive categorization
struct AppRegistry {

    // MARK: - Terminal Apps

    static let terminalAppNames: Set<String> = [
        // Native terminals
        "Terminal",
        "iTerm2",
        "iTerm",

        // Third-party terminals
        "Warp",
        "Alacritty",
        "Hyper",
        "kitty",
        "WezTerm",
        "Ghostty",
        "Rio",
        "Tabby",
        "Terminus",
        "Contour",
    ]

    static let terminalBundleIds: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "co.zeit.hyper",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
    ]

    // MARK: - IDE Apps

    static let ideAppNames: Set<String> = [
        "Cursor",
        "Code",
        "Visual Studio Code",
        "VSCodium",
        "Zed",
        "Fleet",
        "Nova",
        "Sublime Text",
        "Xcode",

        // JetBrains IDEs
        "IntelliJ IDEA",
        "WebStorm",
        "PyCharm",
        "PhpStorm",
        "RubyMine",
        "GoLand",
        "CLion",
        "DataGrip",
        "Rider",
        "AppCode",
        "Android Studio",
    ]

    static let ideBundleIds: Set<String> = [
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.microsoft.VSCode",
        "com.vscodium.VSCodium",
        "dev.zed.Zed",
        "com.apple.dt.Xcode",
    ]

    // MARK: - AI Chat Apps

    static let aiChatAppNames: Set<String> = [
        "Claude",
        "Anthropic",
        "ChatGPT",
        "OpenAI",
        "Gemini",
        "Google AI Studio",
        "Copilot",
        "Perplexity",
        "Poe",
        "Character.AI",
    ]

    static let aiChatBundleIds: Set<String> = [
        "com.anthropic.claude",
        "com.openai.chatgpt",
    ]

    // MARK: - Messaging Apps

    static let messagingAppNames: Set<String> = [
        "Slack",
        "Discord",
        "Microsoft Teams",
        "Teams",
        "Zoom",
        "Messages",
        "Telegram",
        "WhatsApp",
        "Signal",
        "Messenger",
        "WeChat",
    ]

    static let messagingBundleIds: Set<String> = [
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.microsoft.teams",
        "us.zoom.xos",
        "com.apple.MobileSMS",
    ]

    // MARK: - Browser Apps

    static let browserAppNames: Set<String> = [
        "Safari",
        "Google Chrome",
        "Chrome",
        "Firefox",
        "Arc",
        "Microsoft Edge",
        "Brave Browser",
        "Brave",
        "Opera",
        "Vivaldi",
        "Orion",
    ]

    static let browserBundleIds: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",  // Arc
        "com.microsoft.edgemac",
        "com.brave.Browser",
    ]

    // MARK: - Documentation Apps

    static let documentationAppNames: Set<String> = [
        "Notion",
        "Obsidian",
        "Confluence",
        "Craft",
        "Bear",
        "Notes",
        "Apple Notes",
        "Evernote",
        "Roam Research",
        "Logseq",
        "Typora",
        "iA Writer",
    ]

    static let documentationBundleIds: Set<String> = [
        "notion.id",
        "md.obsidian",
        "com.apple.Notes",
    ]

    // MARK: - Ticketing Apps

    static let ticketingAppNames: Set<String> = [
        "Jira",
        "Linear",
        "Asana",
        "Trello",
        "ClickUp",
        "Monday",
        "Basecamp",
        "GitHub Desktop",
        "Tower",
        "Sourcetree",
    ]

    // MARK: - Design Apps

    static let designAppNames: Set<String> = [
        "Figma",
        "Sketch",
        "Adobe XD",
        "Photoshop",
        "Illustrator",
        "Preview",
        "Pixelmator",
        "Affinity Designer",
        "Canva",
    ]

    static let designBundleIds: Set<String> = [
        "com.figma.Desktop",
        "com.bohemiancoding.sketch3",
        "com.apple.Preview",
    ]

    // MARK: - Email Apps

    static let emailAppNames: Set<String> = [
        "Mail",
        "Outlook",
        "Gmail",
        "Spark",
        "Airmail",
        "Mimestream",
        "Mailspring",
    ]

    static let emailBundleIds: Set<String> = [
        "com.apple.mail",
        "com.microsoft.Outlook",
    ]

    // MARK: - Text Editor Apps

    static let textEditorAppNames: Set<String> = [
        "TextEdit",
        "BBEdit",
        "CotEditor",
        "MacVim",
        "Emacs",
        "Vim",
        "neovim",
    ]

    // MARK: - Detection Methods

    /// Detect app category from app name
    static func category(forAppName name: String) -> AppCategory {
        // Fast exact matches first
        if terminalAppNames.contains(name) { return .terminal }
        if ideAppNames.contains(name) { return .ide }
        if aiChatAppNames.contains(name) { return .aiChat }
        if messagingAppNames.contains(name) { return .messaging }
        if browserAppNames.contains(name) { return .browser }
        if documentationAppNames.contains(name) { return .documentation }
        if ticketingAppNames.contains(name) { return .ticketing }
        if designAppNames.contains(name) { return .design }
        if emailAppNames.contains(name) { return .email }
        if textEditorAppNames.contains(name) { return .textEditor }

        let lowercased = name.lowercased()

        // Partial matches
        if terminalAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .terminal
        }
        if lowercased.contains("jetbrains") || ideAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .ide
        }
        if aiChatAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .aiChat
        }
        if messagingAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .messaging
        }
        if browserAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .browser
        }
        if documentationAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .documentation
        }
        if ticketingAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .ticketing
        }
        if designAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .design
        }
        if emailAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .email
        }
        if textEditorAppNames.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .textEditor
        }

        return .generic
    }

    /// Detect app category from bundle ID
    static func category(forBundleId bundleId: String?) -> AppCategory {
        guard let bundleId = bundleId else { return .generic }
        let lowercased = bundleId.lowercased()

        if terminalBundleIds.contains(bundleId) {
            return .terminal
        }
        if ideBundleIds.contains(bundleId) || lowercased.contains("jetbrains") ||
           lowercased.contains("vscode") || lowercased.contains("cursor") {
            return .ide
        }
        if aiChatBundleIds.contains(bundleId) || lowercased.contains("claude") ||
           lowercased.contains("chatgpt") || lowercased.contains("openai") {
            return .aiChat
        }
        if messagingBundleIds.contains(bundleId) || lowercased.contains("slack") ||
           lowercased.contains("discord") || lowercased.contains("teams") {
            return .messaging
        }
        if browserBundleIds.contains(bundleId) || lowercased.contains("safari") ||
           lowercased.contains("chrome") || lowercased.contains("firefox") {
            return .browser
        }
        if documentationBundleIds.contains(bundleId) || lowercased.contains("notion") ||
           lowercased.contains("obsidian") {
            return .documentation
        }
        if designBundleIds.contains(bundleId) || lowercased.contains("figma") ||
           lowercased.contains("sketch") {
            return .design
        }
        if emailBundleIds.contains(bundleId) || lowercased.contains("mail") {
            return .email
        }

        return .generic
    }

    /// Detect app category from running application
    static func category(for app: NSRunningApplication) -> AppCategory {
        // Try bundle ID first (more reliable)
        let bundleCategory = category(forBundleId: app.bundleIdentifier)
        if bundleCategory != .generic {
            return bundleCategory
        }

        // Fall back to app name
        if let name = app.localizedName {
            return category(forAppName: name)
        }

        return .generic
    }

    /// Detect app category from window info
    static func category(for window: WindowInfo) -> AppCategory {
        return category(forAppName: window.ownerName)
    }

    /// Determine best paste mode for a destination app
    static func recommendedPasteMode(for app: NSRunningApplication) -> PasteMode {
        return category(for: app).preferredPasteMode
    }

    /// Determine best paste mode for a destination window
    static func recommendedPasteMode(for window: WindowInfo) -> PasteMode {
        return category(for: window).preferredPasteMode
    }

    // MARK: - Legacy Compatibility

    /// Check if an app is a terminal/IDE (legacy support)
    static func isTerminalOrIDE(_ appName: String) -> Bool {
        let cat = category(forAppName: appName)
        return cat == .terminal || cat == .ide
    }

    /// Check if an app is a terminal/IDE (legacy support)
    static func isTerminalOrIDE(_ app: NSRunningApplication) -> Bool {
        let cat = category(for: app)
        return cat == .terminal || cat == .ide
    }
}
