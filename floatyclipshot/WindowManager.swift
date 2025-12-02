//
//  WindowManager.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import Foundation
import AppKit
import SwiftUI
import Combine

struct WindowInfo: Identifiable, Equatable {
    let id: Int // CGWindowID
    let name: String
    let ownerName: String
    let ownerPID: Int // Process ID for more reliable matching
    let bounds: CGRect

    var displayName: String {
        if name.isEmpty {
            return ownerName
        }
        return "\(ownerName) - \(name)"
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()

    @Published var selectedWindow: WindowInfo?
    @Published var availableWindows: [WindowInfo] = []
    
    // History Window
    private var historyWindow: NSWindow?

    // Debouncing: Track last refresh time to avoid excessive refreshes
    private var lastRefreshTime: Date?
    private let refreshDebounceInterval: TimeInterval = 0.5  // Minimum 0.5s between refreshes

    // Track the previously frontmost app (before our window activated)
    // This solves the focus race condition when user clicks the floating button
    private var previousFrontmostApp: NSRunningApplication?

    private init() {
        // CRITICAL: Capture current frontmost app BEFORE we activate
        // This handles "first click after launch" scenario where user clicks button immediately
        // Without this, previousFrontmostApp would be nil on first click
        if let currentApp = NSWorkspace.shared.frontmostApplication,
           currentApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousFrontmostApp = currentApp
            print("🔄 Initial frontmost app (at launch): \(currentApp.localizedName ?? "Unknown") (\(currentApp.bundleIdentifier ?? "Unknown"))")
        }

        // Monitor frontmost app changes to track previous app
        // This is critical for terminal detection when button is clicked
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Load saved window selection
        if let savedWindow = SettingsManager.shared.loadSelectedWindow() {
            // Verify the window still exists by refreshing the list first
            refreshWindowList()
            // Check if the saved window is in the current list
            if let validWindow = availableWindows.first(where: { $0.id == savedWindow.id }) {
                self.selectedWindow = validWindow
            } else {
                // Window no longer exists, clear the saved selection
                SettingsManager.shared.saveSelectedWindow(nil)
            }
        }
    }

    @objc private func frontmostAppChanged(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            // Store previous frontmost app if it's NOT us
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                previousFrontmostApp = app
                print("🔄 Previous frontmost app: \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "Unknown"))")
            }
        }
    }

    /// Get the app that was frontmost BEFORE we activated
    /// Used for terminal detection when button is clicked (app becomes frontmost)
    func getPreviousFrontmostApp() -> NSRunningApplication? {
        return previousFrontmostApp
    }

    /// Get list of all capturable windows
    func refreshWindowList() {
        // Debounce: Skip if refreshed in last 0.5 seconds
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < refreshDebounceInterval {
            print("⏭️ Skipping window refresh (debounced - last refresh \(String(format: "%.2f", Date().timeIntervalSince(lastRefresh)))s ago)")
            return
        }

        lastRefreshTime = Date()

        // Use .optionAll to get windows from ALL desktops/Spaces, not just current one
        // This allows users to select windows on other desktops
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            print("⚠️ Failed to get window list from CGWindowListCopyWindowInfo")
            availableWindows = []
            return
        }

        var windows: [WindowInfo] = []

        for windowDict in windowList {
            // Extract window information
            guard let windowID = windowDict[kCGWindowNumber as String] as? Int,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            // Skip our own app's windows
            if ownerName.contains("floatyclipshot") || ownerName.contains("FloatingScreenshot") {
                continue
            }

            // Skip system UI elements and small windows
            let windowName = windowDict[kCGWindowName as String] as? String ?? ""

            // Parse bounds
            let x = boundsDict["X"] as? CGFloat ?? 0
            let y = boundsDict["Y"] as? CGFloat ?? 0
            let width = boundsDict["Width"] as? CGFloat ?? 0
            let height = boundsDict["Height"] as? CGFloat ?? 0
            let bounds = CGRect(x: x, y: y, width: width, height: height)

            // Skip very small windows (likely UI elements or minimized windows)
            // Minimized windows often have width/height of 0 or very small values
            if width < 100 || height < 100 {
                continue
            }

            // Skip windows with suspicious bounds (off-screen by large amounts)
            // This catches some hidden/minimized windows that slip through
            if abs(x) > 100000 || abs(y) > 100000 {
                continue
            }

            let ownerPID = windowDict[kCGWindowOwnerPID as String] as? Int ?? 0

            let windowInfo = WindowInfo(
                id: windowID,
                name: windowName,
                ownerName: ownerName,
                ownerPID: ownerPID,
                bounds: bounds
            )

            windows.append(windowInfo)
        }

        // Sort by owner name, then window name
        windows.sort { lhs, rhs in
            if lhs.ownerName == rhs.ownerName {
                return lhs.name < rhs.name
            }
            return lhs.ownerName < rhs.ownerName
        }

        DispatchQueue.main.async { [weak self] in
            self?.availableWindows = windows
        }
    }

    /// Select a window for future captures
    func selectWindow(_ window: WindowInfo?) {
        DispatchQueue.main.async { [weak self] in
            self?.selectedWindow = window

            if let window = window {
                print("🎯 Window selected: \(window.displayName) (ID: \(window.id))")
                print("   Bounds: \(window.bounds)")
            } else {
                print("🎯 Window selection cleared (back to full screen)")
            }

            // Save to settings
            SettingsManager.shared.saveSelectedWindow(window)
        }
    }

    /// Clear selected window (back to full screen mode)
    func clearSelection() {
        selectWindow(nil)
    }

    /// Get display text for current selection
    var selectionDisplayText: String {
        if let window = selectedWindow {
            return "📍 \(window.displayName)"
        }
        return "🖥️ Full Screen"
    }

    /// Check if a window still exists (checks ALL desktops, not just current one)
    func isWindowValid(_ window: WindowInfo) -> Bool {
        // Use .optionAll to check windows on ALL desktops/Spaces (must match refreshWindowList)
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            print("⚠️ Window validation: Failed to get window list")
            return false
        }

        for windowDict in windowList {
            if let windowID = windowDict[kCGWindowNumber as String] as? Int,
               windowID == window.id {
                print("✅ Window validation: Window \(window.id) (\(window.displayName)) still exists")
                return true
            }
        }

        print("⚠️ Window validation: Window \(window.id) (\(window.displayName)) not found (may have been closed)")
        return false
    }
    
    func showHistoryWindow() {
        // If window exists and is visible, just focus it
        if let window = historyWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create new window
        let historyView = ClipboardHistoryView()
        let controller = NSHostingController(rootView: historyView)
        
        let window = NSWindow(contentViewController: controller)
        window.title = "Clipboard History"
        window.setContentSize(NSSize(width: 320, height: 500))
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        
        // Position near mouse or center
        window.center()
        
        // Keep reference
        self.historyWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
