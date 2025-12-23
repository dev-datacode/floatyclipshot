//
//  SecuritySettingsWindowController.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Window controller for the Security Settings panel

import AppKit
import SwiftUI

/// Manages the Security Settings window
final class SecuritySettingsWindowController {
    static let shared = SecuritySettingsWindowController()

    private var window: NSWindow?

    private init() {}

    /// Show the security settings window
    func showWindow() {
        // If window exists and is visible, just bring it to front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Create the SwiftUI content
        let contentView = SecuritySettingsView()

        // Create hosting controller
        let hostingController = NSHostingController(rootView: contentView)

        // Create window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        newWindow.contentViewController = hostingController
        newWindow.title = "Security & Privacy Settings"
        newWindow.titlebarAppearsTransparent = false
        newWindow.isMovableByWindowBackground = true
        newWindow.center()

        // Set minimum size
        newWindow.minSize = NSSize(width: 400, height: 500)

        // Make it a floating panel style
        newWindow.level = .floating
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Store reference and show
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Close the security settings window
    func closeWindow() {
        window?.close()
        window = nil
    }

    /// Check if window is currently visible
    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }
}
