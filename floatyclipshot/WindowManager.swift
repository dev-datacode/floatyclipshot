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

struct WindowInfo: Identifiable, Equatable, Hashable {
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
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
            // Store the placeholder saved window initially
            self.selectedWindow = savedWindow
            
            // Trigger a refresh to verify and update it with real bounds/PID
            refreshWindowList()
        }
    }

    @objc private func frontmostAppChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let bundleID = app.bundleIdentifier
        let isUs = bundleID == Bundle.main.bundleIdentifier
        
        Task { @MainActor in
            if !isUs {
                self.previousFrontmostApp = app
                print("🔄 Previous frontmost app: \(app.localizedName ?? "Unknown") (\(bundleID ?? "Unknown"))")
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
            return
        }
        performRefresh()
    }

    /// Force refresh window list, bypassing debounce
    func forceRefreshWindowList() {
        print("🔄 Force refreshing window list (bypassing debounce)")
        performRefresh()
    }

    private func performRefresh() {
        lastRefreshTime = Date()

        // Move expensive window listing to background thread
        Task.detached(priority: .userInitiated) {
            // Use autoreleasepool to ensure temporary CF objects are cleaned up promptly
            let windows: [WindowInfo] = autoreleasepool {
                guard let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
                    print("⚠️ Failed to get window list from CGWindowListCopyWindowInfo")
                    return []
                }

                var results: [WindowInfo] = []

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

                    let windowName = windowDict[kCGWindowName as String] as? String ?? ""

                    // Parse bounds
                    let x = boundsDict["X"] as? CGFloat ?? 0
                    let y = boundsDict["Y"] as? CGFloat ?? 0
                    let width = boundsDict["Width"] as? CGFloat ?? 0
                    let height = boundsDict["Height"] as? CGFloat ?? 0
                    let bounds = CGRect(x: x, y: y, width: width, height: height)

                    // Skip very small windows
                    if width < 100 || height < 100 {
                        continue
                    }

                    // Skip windows with suspicious bounds
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

                    results.append(windowInfo)
                }
                return results
            }

            if windows.isEmpty {
                await MainActor.run { self.availableWindows = [] }
                return
            }

            // Sort by owner name, then window name
            let windowsResult = windows.sorted { lhs, rhs in
                if lhs.ownerName == rhs.ownerName {
                    return lhs.name < rhs.name
                }
                return lhs.ownerName < rhs.ownerName
            }

            // Update state on Main Actor
            await MainActor.run {
                self.availableWindows = windowsResult
                
                // Update selected window if it exists in the new list
                if let current = self.selectedWindow {
                    if let updated = windowsResult.first(where: { $0.id == current.id }) {
                        self.selectedWindow = updated
                    }
                }
            }
        }
    }

    /// Select a window for future captures
    func selectWindow(_ window: WindowInfo?) {
        self.selectedWindow = window

        if let window = window {
            print("🎯 Window selected: \(window.displayName) (ID: \(window.id))")
        } else {
            print("🎯 Window selection cleared (back to full screen)")
        }

        // Save to settings
        SettingsManager.shared.saveSelectedWindow(window)
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
