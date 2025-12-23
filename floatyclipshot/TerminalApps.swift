//
//  TerminalApps.swift
//  floatyclipshot
//
//  Single source of truth for terminal/IDE app detection
//

import Foundation
import AppKit

/// Apps that can be paired FROM (terminals and IDEs with integrated terminals)
/// These are apps where Cmd+Shift+B should trigger a paired window capture
enum TerminalApps {
    /// App names that are considered terminals/IDEs
    static let appNames: Set<String> = [
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

        // IDEs with integrated terminals
        "Cursor",
        "Code",
        "Visual Studio Code",
        "VSCodium",
        "Zed",
        "Fleet",
        "Nova",
        "Sublime Text",

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

        // Other dev tools
        "Xcode",
        "Emacs",
        "MacVim",
    ]

    /// Bundle identifiers for more reliable matching
    static let bundleIdentifiers: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "co.zeit.hyper",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.microsoft.VSCode",
        "com.vscodium.VSCodium",
        "dev.zed.Zed",
        "com.jetbrains.intellij",
        "com.jetbrains.WebStorm",
        "com.jetbrains.pycharm",
        "com.apple.dt.Xcode",
    ]

    /// Check if an app name matches a terminal/IDE
    static func isTerminal(_ appName: String) -> Bool {
        // Exact match first
        if appNames.contains(appName) {
            return true
        }

        // Case-insensitive contains for partial matches
        let lowercased = appName.lowercased()
        return appNames.contains { name in
            lowercased.contains(name.lowercased())
        }
    }

    /// Check if a bundle identifier matches a terminal/IDE
    static func isTerminalBundle(_ bundleId: String?) -> Bool {
        guard let bundleId = bundleId else { return false }

        // Exact match
        if bundleIdentifiers.contains(bundleId) {
            return true
        }

        // Partial match for JetBrains and other families
        let lowercased = bundleId.lowercased()
        return lowercased.contains("jetbrains") ||
               lowercased.contains("iterm") ||
               lowercased.contains("terminal") ||
               lowercased.contains("warp") ||
               lowercased.contains("vscode") ||
               lowercased.contains("cursor")
    }

    /// Check if a running application is a terminal/IDE
    static func isTerminal(_ app: NSRunningApplication) -> Bool {
        if isTerminalBundle(app.bundleIdentifier) {
            return true
        }
        if let name = app.localizedName, isTerminal(name) {
            return true
        }
        return false
    }
}
