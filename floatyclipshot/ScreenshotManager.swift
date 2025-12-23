import Foundation
import AppKit
import CoreGraphics
import ApplicationServices
import UserNotifications // For modern notifications
import Combine
import SwiftUI

@MainActor
final class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()

    // Published state for auto-pairing UI
    @Published var showQuickPicker = false
    @Published var quickPickerTargets: [WindowInfo] = []
    @Published var toastMessage: String?
    @Published var toastType: ToastType = .info

    // Auto-pairing state
    @Published var autoPairingStatus: AutoPairingStatus = .none

    enum ToastType {
        case success, error, info
    }

    enum AutoPairingStatus {
        case none           // No auto-pair target detected
        case ready          // Single target auto-detected (ready to capture)
        case multiple       // Multiple targets (will show picker)
        case paired         // Explicit pairing exists
    }

    private init() {}

    // MARK: - Source Window Detection (Universal)

    /// Get the WindowInfo for the currently active source window
    /// Works for ANY app - terminals, IDEs, Claude, Slack, browsers, etc.
    /// Used for pairing lookup when Cmd+Shift+B is pressed
    func getActiveSourceWindow() -> WindowInfo? {
        // Determine which app to check (current frontmost or previous)
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        let targetApp: NSRunningApplication?

        if currentFrontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            // We're frontmost (button click) - use previous app
            targetApp = WindowManager.shared.getPreviousFrontmostApp()
        } else {
            // We're in background (hotkey) - use current app
            targetApp = currentFrontmost
        }

        guard let app = targetApp else { return nil }

        // Get the frontmost window of this app from the window list
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find windows belonging to this app, sorted by layer (frontmost first)
        for windowDict in windowList {
            guard let ownerPID = windowDict[kCGWindowOwnerPID as String] as? Int,
                  ownerPID == Int(app.processIdentifier),
                  let windowID = windowDict[kCGWindowNumber as String] as? Int,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            let windowName = windowDict[kCGWindowName as String] as? String ?? ""
            let x = boundsDict["X"] as? CGFloat ?? 0
            let y = boundsDict["Y"] as? CGFloat ?? 0
            let width = boundsDict["Width"] as? CGFloat ?? 0
            let height = boundsDict["Height"] as? CGFloat ?? 0

            // Skip small windows (toolbars, etc.)
            guard width >= 100 && height >= 100 else { continue }

            return WindowInfo(
                id: windowID,
                name: windowName,
                ownerName: ownerName,
                ownerPID: ownerPID,
                bounds: CGRect(x: x, y: y, width: width, height: height)
            )
        }

        return nil
    }

    /// Legacy alias for terminal detection
    func getActiveTerminalWindow() -> WindowInfo? {
        return getActiveSourceWindow()
    }

    /// Get the app category for the current source window
    func getSourceAppCategory() -> AppCategory {
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        let targetApp: NSRunningApplication?

        if currentFrontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            targetApp = WindowManager.shared.getPreviousFrontmostApp()
        } else {
            targetApp = currentFrontmost
        }

        guard let app = targetApp else { return .generic }
        return AppRegistry.category(for: app)
    }

    /// Check if the source app supports file path pasting (terminals, IDEs)
    func sourceAppSupportsFilePath() -> Bool {
        let category = getSourceAppCategory()
        return category == .terminal || category == .ide || category == .textEditor
    }

    // MARK: - Same-Space Auto-Pairing

    /// Target apps that can be auto-paired (simulators, browsers, etc.)
    private static let autoTargetApps: Set<String> = [
        "Simulator",        // iOS Simulator
        "Android Emulator", // Android Studio Emulator
        "Safari",           // Web browser
        "Google Chrome",    // Web browser
        "Firefox",          // Web browser
        "Arc",              // Web browser
        "Microsoft Edge",   // Web browser
        "Brave Browser",    // Web browser
        "Preview",          // Image viewer
    ]

    /// Get simulators/browsers on the current Space (on-screen only)
    /// Uses .optionOnScreenOnly to filter to current Space
    func getOnScreenTargets() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var targets: [WindowInfo] = []

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? Int,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            // Only include auto-target apps
            guard Self.autoTargetApps.contains(ownerName) else { continue }

            // Skip our own windows
            if ownerName.contains("floatyclipshot") || ownerName.contains("FloatingScreenshot") {
                continue
            }

            let windowName = windowDict[kCGWindowName as String] as? String ?? ""
            let ownerPID = windowDict[kCGWindowOwnerPID as String] as? Int ?? 0
            let x = boundsDict["X"] as? CGFloat ?? 0
            let y = boundsDict["Y"] as? CGFloat ?? 0
            let width = boundsDict["Width"] as? CGFloat ?? 0
            let height = boundsDict["Height"] as? CGFloat ?? 0

            // Skip small windows
            guard width >= 100 && height >= 100 else { continue }

            let windowInfo = WindowInfo(
                id: windowID,
                name: windowName,
                ownerName: ownerName,
                ownerPID: ownerPID,
                bounds: CGRect(x: x, y: y, width: width, height: height)
            )
            targets.append(windowInfo)
        }

        // Sort: Simulators first, then browsers, then by window name
        targets.sort { a, b in
            let aIsSimulator = a.ownerName == "Simulator"
            let bIsSimulator = b.ownerName == "Simulator"
            if aIsSimulator != bIsSimulator { return aIsSimulator }
            if a.ownerName != b.ownerName { return a.ownerName < b.ownerName }
            return a.name < b.name
        }

        return targets
    }

    /// Get simulators only (for focused capture)
    func getOnScreenSimulators() -> [WindowInfo] {
        return getOnScreenTargets().filter { $0.ownerName == "Simulator" }
    }

    /// Update auto-pairing status based on current state
    /// Called when user is in a terminal to show button indicator
    func updateAutoPairingStatus() {
        // Check for GROUP-BASED pairing first (new system)
        if let sourceWindow = getActiveSourceWindow() {
            let allWindows = WindowManager.shared.availableWindows
            let groupTargets = GroupPairingManager.shared.getCaptureTargets(forPrimary: sourceWindow, allWindows: allWindows)
            if !groupTargets.isEmpty {
                autoPairingStatus = .paired
                return
            }
        }

        // Check if there's an explicit pairing (legacy system)
        if let terminalWindow = getActiveTerminalWindow(),
           PairingManager.shared.findTargetForTerminal(terminalWindow) != nil {
            autoPairingStatus = .paired
            return
        }

        // Check on-screen targets
        let targets = getOnScreenSimulators()  // Prefer simulators for auto-pairing
        switch targets.count {
        case 0:
            autoPairingStatus = .none
        case 1:
            autoPairingStatus = .ready
        default:
            autoPairingStatus = .multiple
        }
    }

    /// Show toast message
    func showToast(_ message: String, type: ToastType = .info) {
        DispatchQueue.main.async {
            self.toastMessage = message
            self.toastType = type

            // Auto-hide after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if self.toastMessage == message {
                    self.toastMessage = nil
                }
            }
        }
    }

    /// Capture with a specific target window (for quick picker selection)
    /// Now supports universal window-to-window pairing with smart paste mode
    func captureWithTarget(_ targetWindow: WindowInfo, andCreatePairing: Bool = true, pasteMode: PasteMode = .auto) {
        let sourceWindow = getActiveSourceWindow()

        // Optionally create pairing for next time
        if andCreatePairing, let source = sourceWindow {
            let windowPairing = PairingManager.shared.createPairing(
                from: source,
                to: targetWindow,
                pasteMode: pasteMode
            )
            showToast("Paired: \(windowPairing.displayName)", type: .success)
        }

        // Capture with appropriate paste mode
        captureWithPasteMode(targetWindow, pasteMode: pasteMode, sourceWindow: sourceWindow)
    }

    /// Capture with a specific target and explicit paste mode
    func captureWithTarget(_ targetWindow: WindowInfo, pasteMode: PasteMode) {
        captureWithTarget(targetWindow, andCreatePairing: true, pasteMode: pasteMode)
    }

    // MARK: - AppleScript Helper

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("⚠️ AppleScript error: \(error)")
                return nil
            }
            return output.stringValue
        }
        return nil
    }

    /// Get the active document/folder path from the app's focused window using Accessibility API
    /// Works for VS Code, Cursor, Xcode, Finder, etc.
    private func getDocumentPath(for app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        let appRef = AXUIElementCreateApplication(pid)
        
        var focusedWindow: AnyObject?
        // Get focused window
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let focusedWindow = focusedWindow else {
            return nil
        }
        
        let windowRef = unsafeBitCast(focusedWindow, to: AXUIElement.self)
        
        // Get document URL (kAXDocumentAttribute)
        var documentURL: AnyObject?
        let result = AXUIElementCopyAttributeValue(windowRef, kAXDocumentAttribute as CFString, &documentURL)
        
        if result == .success, let urlString = documentURL as? String {
            // Handle "file://" URLs
            if let url = URL(string: urlString) {
                let path = url.path
                print("✅ Found document path via Accessibility: \(path)")
                
                // If it's a file, return parent directory. If directory, return it.
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
                    return isDir.boolValue ? path : (path as NSString).deletingLastPathComponent
                }
                return path
            }
        }
        return nil
    }

    /// Get the current working directory of a terminal application
    /// - Parameter app: The running terminal application
    /// - Returns: The current working directory path, or nil if unable to determine
    private func getCurrentWorkingDirectory(for app: NSRunningApplication) -> String? {
        // 1. Try AppleScript for supported terminals (Most accurate for Shell CWD)
        if let bundleID = app.bundleIdentifier {
            if bundleID == "com.apple.Terminal" {
                let script = """
                tell application "Terminal"
                    if (count of windows) > 0 then
                        try
                            return POSIX path of (target of front window as alias)
                        on error
                            return ""
                        end try
                    end if
                    return ""
                end tell
                """
                if let path = runAppleScript(script), !path.isEmpty {
                    print("✅ Found cwd via AppleScript (Terminal): \(path)")
                    return path
                }
            } else if bundleID == "com.googlecode.iterm2" {
                let script = """
                tell application "iTerm"
                    if (count of windows) > 0 then
                        try
                            tell current session of current window
                                return path
                            end tell
                        on error
                            return ""
                        end try
                    end if
                    return ""
                end tell
                """
                if let path = runAppleScript(script), !path.isEmpty {
                    print("✅ Found cwd via AppleScript (iTerm2): \(path)")
                    return path
                }
            }
        }
        
        // 2. Try Accessibility API (Best for VS Code, Cursor, Xcode)
        // This finds the path of the open file/project
        if let docPath = getDocumentPath(for: app) {
            return docPath
        }

        // 3. Fallback to lsof (Process CWD) - Least accurate for GUI apps
        guard let pid = app.processIdentifier as Int32? else {
            print("⚠️ Unable to get PID for app")
            return nil
        }

        print("🔍 Getting cwd for PID \(pid)...")

        // Use lsof to get the current working directory of the process
        let task = Process()
        task.executableURL = URL(filePath: "/usr/sbin/lsof")
        task.arguments = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()  // Suppress stderr

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                print("⚠️ Unable to decode lsof output")
                return nil
            }

            // Parse lsof output - format is like:
            // p<pid>
            // n<path>
            let lines = output.split(separator: "\n")
            for line in lines {
                if line.hasPrefix("n") {
                    let path = String(line.dropFirst())  // Remove 'n' prefix
                    print("✅ Found cwd: \(path)")
                    return path
                }
            }

            print("⚠️ Could not parse cwd from lsof output")
            return nil
        } catch {
            print("⚠️ Failed to run lsof: \(error)")
            return nil
        }
    }

    /// Check if the target application is a terminal
    /// Handles both button clicks (uses previous frontmost app) and hotkeys (uses current frontmost app)
    private func isFrontmostAppTerminal() -> Bool {
        let currentFrontmost = NSWorkspace.shared.frontmostApplication

        // CRITICAL: If WE are frontmost (button click), use the PREVIOUS frontmost app
        // If we're in background (hotkey), use the CURRENT frontmost app
        let targetApp: NSRunningApplication?
        if currentFrontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            // We're frontmost (button click) - use previous app
            targetApp = WindowManager.shared.getPreviousFrontmostApp()
            print("🔍 Terminal detection: Using PREVIOUS frontmost app (button click path)")
        } else {
            // We're in background (hotkey) - use current app
            targetApp = currentFrontmost
            print("🔍 Terminal detection: Using CURRENT frontmost app (hotkey path)")
        }

        guard let app = targetApp else {
            print("⚠️ Terminal detection: No target app detected")
            return false
        }

        let appName = app.localizedName ?? "Unknown"
        let bundleID = app.bundleIdentifier ?? "Unknown"

        print("🔍 Terminal detection check:")
        print("   App: \(appName)")
        print("   Bundle ID: \(bundleID)")

        // Use centralized TerminalApps detection
        let isTerminal = TerminalApps.isTerminal(app)
        print("   Is terminal: \(isTerminal ? "✅ YES" : "❌ NO")")
        return isTerminal
    }

    // MARK: - Permission Checks

    /// Check if Accessibility permission is granted (public wrapper)
    func isAccessibilityGranted() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Check if Screen Recording permission is likely granted
    /// We verify this by checking if we can see window titles from other apps
    func isScreenRecordingGranted() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        // If we can see more than just our own windows and they have names, we probably have permission
        // Without permission, we usually get a list but 'kCGWindowName' is missing or empty for other apps
        for window in windowList {
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               ownerName != "floatyclipshot", // Not us
               let windowName = window[kCGWindowName as String] as? String,
               !windowName.isEmpty {
                return true
            }
        }
        
        // Fallback: If no windows are open, we can't be sure, but usually Finder/Dock are always there
        // If we see "Dock" or "Finder" as owner, it's a good sign
        for window in windowList {
             if let ownerName = window[kCGWindowOwnerName as String] as? String,
                (ownerName == "Dock" || ownerName == "Finder") {
                 return true
             }
        }

        return false
    }

    /// Open System Settings to the specific page
    func openSystemSettings(for permission: PermissionType) {
        let urlString: String
        switch permission {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    enum PermissionType {
        case accessibility
        case screenRecording
    }

    // MARK: - Accessibility Permission

    /// Check if the app has Accessibility permission for CGEvent posting
    private func checkAccessibilityPermission() -> Bool {
        // Check without prompting (we'll handle the prompt ourselves)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Show alert guiding user to grant Accessibility permission
    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            // Check if app is in foreground to avoid deadlock
            if NSApplication.shared.isActive {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = """
Auto-paste requires Accessibility permission to simulate keyboard events.

Steps to enable:
1. Open System Preferences → Security & Privacy
2. Click Privacy tab → Accessibility
3. Click the lock icon to make changes
4. Enable "floatyclipshot" in the list

Alternative: Use \(HotkeyManager.shared.hotkeyDisplayString) to capture without auto-paste.
"""
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Cancel")

                if alert.runModal() == .alertFirstButtonReturn {
                    // Open System Preferences to Accessibility pane
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                            } else {
                                // App in background - use notification
                                                    let content = UNMutableNotificationContent()
                                                    content.title = "Accessibility Permission Required"
                                                    content.body = "Auto-paste needs Accessibility permission. Check System Preferences → Security & Privacy → Accessibility"
                                                    content.sound = UNNotificationSound.default            
                                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                                UNUserNotificationCenter.current().add(request) { error in
                                    if let error = error {
                                        print("⚠️ Failed to deliver notification: \(error.localizedDescription)")
                                    }
                                }
                            }        }
    }

    /// Capture the selected window or full screen and copy to clipboard
    func captureFullScreen() {
        var arguments = ["-x", "-c", "-T", "0", "-o"]  // -T 0 disables thumbnail, -o disables shadow for faster capture

        // If a window is selected, capture only that window
        if let window = WindowManager.shared.selectedWindow {
            // Check if window still exists
            if WindowManager.shared.isWindowValid(window) {
                arguments.insert("-l\(window.id)", at: 0)
            } else {
                // Window no longer exists, clear selection and capture full screen
                WindowManager.shared.clearSelection()
                showWindowClosedAlert()
            }
        }

        runScreencapture(arguments: arguments) {
            // Give the clipboard a moment to update, then trigger clipboard manager
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // The ClipboardManager will automatically detect this change
            }
        }
    }

    /// Capture to clipboard and auto-paste (fallback when no source window detected)
    /// Used for universal pairing when source app cannot be determined
    private func captureToClipboardAndPaste() {
        var arguments = ["-x", "-c", "-T", "0", "-o"]  // -T 0 disables thumbnail, -o disables shadow for faster capture

        // If a window is selected, capture only that window
        if let window = WindowManager.shared.selectedWindow {
            if WindowManager.shared.isWindowValid(window) {
                arguments.insert("-l\(window.id)", at: 0)
            } else {
                WindowManager.shared.clearSelection()
                showWindowClosedAlert()
            }
        }

        // Capture current clipboard state BEFORE screenshot
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        runScreencapture(arguments: arguments) {
            // Poll clipboard until it updates (or timeout)
            self.waitForClipboardUpdate(
                initialChangeCount: initialChangeCount,
                timeout: 2.0
            ) { success in
                if success {
                    // Clipboard updated - paste it
                    DispatchQueue.main.async {
                        let pasteSuccess = self.simulatePaste()
                        if pasteSuccess {
                            print("✅ Screenshot captured and pasted (clipboard mode)")
                        }
                    }
                } else {
                    print("⚠️ Clipboard update timeout in clipboard mode")
                    DispatchQueue.main.async {
                        self.showPasteFailureNotification(
                            "Screenshot capture timed out. Try pasting manually with ⌘V."
                        )
                    }
                }
            }
        }
    }

    /// Capture the selected window or full screen, copy to clipboard, and auto-paste
    /// Now supports UNIVERSAL window-to-window pairing (not just terminals)
    func captureAndPaste() {
        print("📸 captureAndPaste() called")

        // Get source window info for universal pairing
        guard let sourceWindow = getActiveSourceWindow() else {
            print("   ⚠️ No source window detected, using clipboard mode")
            captureToClipboardAndPaste()
            return
        }

        let sourceCategory = AppRegistry.category(for: sourceWindow)
        print("   📍 Source: \(sourceWindow.ownerName) (\(sourceCategory))")

        // 0. Check for GROUP-BASED pairing first (new simplified system)
        if GroupPairingManager.shared.isEnabled {
            let allWindows = WindowManager.shared.availableWindows
            let groupTargets = GroupPairingManager.shared.getCaptureTargets(forPrimary: sourceWindow, allWindows: allWindows)

            if !groupTargets.isEmpty {
                print("   🔗 Found \(groupTargets.count) group target(s)")

                if groupTargets.count == 1 {
                    // Single target - capture directly
                    let target = groupTargets[0]
                    print("   🎯 Capturing group target: \(target.displayName)")
                    let pasteMode: PasteMode = sourceCategory.preferredPasteMode
                    captureWithPasteMode(target, pasteMode: pasteMode, sourceWindow: sourceWindow)
                    showToast("Captured \(target.name.isEmpty ? target.ownerName : target.name)", type: .success)
                    return
                } else {
                    // Multiple targets - show picker
                    print("   📋 Multiple group targets, showing picker")
                    DispatchQueue.main.async {
                        self.quickPickerTargets = groupTargets
                        self.showQuickPicker = true
                    }
                    showToast("Select a window to capture", type: .info)
                    return
                }
            }
        }

        // 1. Check for EXISTING pairing (legacy system - works for ANY app)
        if let pairing = PairingManager.shared.pairingForSource(sourceWindow),
           let targetWindow = PairingManager.shared.findCaptureTarget(for: pairing) {
            print("   🔗 Found paired target: \(targetWindow.displayName)")
            print("   📋 Paste mode: \(pairing.pasteMode.displayName)")

            // Record usage for analytics
            PairingManager.shared.recordUsage(pairing)

            // Use the pairing's paste mode
            captureWithPasteMode(targetWindow, pasteMode: pairing.pasteMode, sourceWindow: sourceWindow)
            showToast("Captured \(targetWindow.name.isEmpty ? targetWindow.ownerName : targetWindow.name)", type: .success)
            return
        }

        // 2. Auto-detect targets on the same Space
        let onScreenTargets = getOnScreenTargets()
        print("   🔍 Found \(onScreenTargets.count) target(s) on current Space")

        // Prefer simulators for auto-pairing
        let simulators = onScreenTargets.filter { $0.ownerName == "Simulator" }

        if simulators.count == 1 {
            // Single simulator - auto-capture and create pairing
            let target = simulators[0]
            print("   🎯 Auto-capturing single simulator: \(target.displayName)")

            // Auto-create pairing with smart paste mode
            let pairing = PairingManager.shared.createPairing(
                from: sourceWindow,
                to: target,
                pasteMode: .auto
            )
            print("   🔗 Auto-paired: \(pairing.displayName) (mode: \(pairing.pasteMode.displayName))")

            captureWithPasteMode(target, pasteMode: pairing.pasteMode, sourceWindow: sourceWindow)
            showToast("Captured \(target.name.isEmpty ? "Simulator" : target.name)", type: .success)
            return

        } else if simulators.count > 1 {
            // Multiple simulators - show picker
            print("   📋 Multiple simulators found, showing picker")
            DispatchQueue.main.async {
                self.quickPickerTargets = simulators
                self.showQuickPicker = true
            }
            showToast("Select a simulator to capture", type: .info)
            return
        }

        // No simulators - try other targets
        if onScreenTargets.count == 1 {
            let target = onScreenTargets[0]
            print("   🌐 Auto-capturing single target: \(target.displayName)")

            let pairing = PairingManager.shared.createPairing(
                from: sourceWindow,
                to: target,
                pasteMode: .auto
            )

            captureWithPasteMode(target, pasteMode: pairing.pasteMode, sourceWindow: sourceWindow)
            showToast("Captured \(target.name.isEmpty ? target.ownerName : target.name)", type: .success)
            return

        } else if onScreenTargets.count > 1 {
            print("   📋 Multiple targets found, showing picker")
            DispatchQueue.main.async {
                self.quickPickerTargets = onScreenTargets
                self.showQuickPicker = true
            }
            showToast("Select a window to capture", type: .info)
            return
        }

        // 3. No pairings and no auto-targets - fallback based on source app type
        print("   ℹ️ No targets found, using fallback behavior")

        if sourceCategory == .terminal || sourceCategory == .ide {
            // Terminal/IDE - capture full screen with file path paste
            captureAndPasteToTerminal()
            return
        }

        // Non-terminal - use clipboard mode
        print("   ℹ️ Using clipboard mode for \(sourceCategory)")
        // Regular app - use clipboard + auto-paste
        var arguments = ["-x", "-c", "-T", "0", "-o"]  // -T 0 disables thumbnail, -o disables shadow for faster capture

        // If a window is selected, capture only that window
        if let window = WindowManager.shared.selectedWindow {
            // Check if window still exists
            if WindowManager.shared.isWindowValid(window) {
                arguments.insert("-l\(window.id)", at: 0)
            } else {
                // Window no longer exists, clear selection and capture full screen
                WindowManager.shared.clearSelection()
                showWindowClosedAlert()
            }
        }

        // CRITICAL: Capture current clipboard state BEFORE screenshot
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        runScreencapture(arguments: arguments) {
            // Poll clipboard until it updates (or timeout)
            self.waitForClipboardUpdate(
                initialChangeCount: initialChangeCount,
                timeout: 2.0
            ) { success in
                if success {
                    // Clipboard updated successfully - safe to paste
                    DispatchQueue.main.async {
                        let pasteSuccess = self.simulatePaste()
                        if pasteSuccess {
                            print("✅ Screenshot captured and pasted successfully")
                        }
                        // If paste failed, simulatePaste() already showed error
                    }
                } else {
                    // Timeout - clipboard didn't update in time
                    print("⚠️ Clipboard update timeout")
                    DispatchQueue.main.async {
                        self.showPasteFailureNotification(
                            "Screenshot capture timed out. The screenshot may still be in clipboard - try pasting manually with ⌘V."
                        )
                    }
                }
            }
        }
    }

    /// Special handling for terminal apps - save to current working directory and copy file path
    private func captureAndPasteToTerminal() {
        // Get the target terminal app
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        let targetApp: NSRunningApplication?

        if currentFrontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            targetApp = WindowManager.shared.getPreviousFrontmostApp()
        } else {
            targetApp = currentFrontmost
        }

        // Generate filename with timestamp
        let fileName = "Screenshot-\(dateFormatter.string(from: Date())).png"

        // Try to get terminal's current working directory, fallback to Desktop
        let savePath: URL
        if let app = targetApp, let cwd = getCurrentWorkingDirectory(for: app) {
            // Create screenshots subdirectory in cwd
            let cwdURL = URL(filePath: cwd)
            let screenshotsDir = cwdURL.appendingPathComponent("FloatyClipshot/tmp")

            // Try to create the directory if it doesn't exist
            do {
                try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
                print("✅ Using terminal's cwd screenshots dir: \(screenshotsDir.path)")
                savePath = screenshotsDir.appendingPathComponent(fileName)
            } catch {
                print("⚠️ Failed to create screenshots directory: \(error)")
                print("   Falling back to Desktop")
                savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")
            }
        } else {
            print("⚠️ Could not get terminal cwd, falling back to Desktop")
            savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")
        }

        var arguments = ["-x", "-T", "0", savePath.path]  // -T 0 disables thumbnail for faster capture

        // If a window is selected, capture only that window
        if let window = WindowManager.shared.selectedWindow {
            if WindowManager.shared.isWindowValid(window) {
                arguments.insert("-l\(window.id)", at: 0)
                arguments.append("-o") // Disable shadow
            } else {
                WindowManager.shared.clearSelection()
                showWindowClosedAlert()
            }
        }

        // Save screenshot to determined path (cwd or Desktop)
        runScreencapture(arguments: arguments) {
            // Verify file was created before proceeding
            DispatchQueue.main.async {
                // Add small delay to ensure file system has written the file
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard FileManager.default.fileExists(atPath: savePath.path) else {
                        print("⚠️ Screenshot save failed - file not created at \(savePath.path)")
                        self.showPasteFailureNotification(
                            "Failed to save screenshot. Check disk space and permissions."
                        )
                        return
                    }

                    // Copy file path to clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(savePath.path, forType: .string)

                    print("✅ File path copied to clipboard: \(savePath.path)")
                    print("   Auto-pasting file path...")

                    // Auto-paste the file path at cursor position (Cmd+V simulation)
                    // Small delay to ensure clipboard is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.simulatePaste()
                        print("✅ Auto-paste triggered - file path should appear at cursor")
                    }
                }
            }
        }
    }

    /// Capture a specific paired target window and paste the file path to terminal
    /// Used when a terminal has a paired target window configured
    private func captureAndPasteWithPairedTarget(_ targetWindow: WindowInfo) {
        // Get the terminal app for saving to its cwd
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        let terminalApp: NSRunningApplication?

        if currentFrontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            terminalApp = WindowManager.shared.getPreviousFrontmostApp()
        } else {
            terminalApp = currentFrontmost
        }

        // Generate filename with timestamp
        let fileName = "Screenshot-\(dateFormatter.string(from: Date())).png"

        // Try to get terminal's current working directory, fallback to Desktop
        let savePath: URL
        if let app = terminalApp, let cwd = getCurrentWorkingDirectory(for: app) {
            let cwdURL = URL(filePath: cwd)
            let screenshotsDir = cwdURL.appendingPathComponent("FloatyClipshot/tmp")

            do {
                try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
                print("✅ Using terminal's cwd screenshots dir: \(screenshotsDir.path)")
                savePath = screenshotsDir.appendingPathComponent(fileName)
            } catch {
                print("⚠️ Failed to create screenshots directory: \(error)")
                savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")
            }
        } else {
            print("⚠️ Could not get terminal cwd, falling back to Desktop")
            savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")
        }

        // CRITICAL: Capture the PAIRED target window, not the global selection
        var arguments = ["-x", "-T", "0", savePath.path]

        // Validate target window still exists
        if WindowManager.shared.isWindowValid(targetWindow) {
            arguments.insert("-l\(targetWindow.id)", at: 0)
            arguments.append("-o") // Disable shadow for speed
            print("🎯 Capturing paired target window: \(targetWindow.displayName) (ID: \(targetWindow.id))")
        } else {
            print("⚠️ Paired target window no longer exists, capturing full screen")
            // Could optionally show an alert here
        }

        runScreencapture(arguments: arguments) {
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard FileManager.default.fileExists(atPath: savePath.path) else {
                        print("⚠️ Screenshot save failed - file not created at \(savePath.path)")
                        self.showPasteFailureNotification(
                            "Failed to save screenshot. Check disk space and permissions."
                        )
                        return
                    }

                    // Copy file path to clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(savePath.path, forType: .string)

                    print("✅ File path copied to clipboard: \(savePath.path)")
                    print("   Auto-pasting file path...")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.simulatePaste()
                        print("✅ Auto-paste triggered - file path should appear at cursor")
                    }
                }
            }
        }
    }

    /// Show notification when saving screenshot for terminal
    private func showTerminalPasteNotification(fileName: String, path: String) {
        DispatchQueue.main.async {
            if NSApplication.shared.isActive {
                let alert = NSAlert()
                alert.messageText = "Screenshot Saved for Terminal"
                alert.informativeText = """
Saved to Desktop: \(fileName)

File path copied to clipboard - paste in terminal with ⌘V.

(Terminals only accept text, not images)
"""
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.addButton(withTitle: "Open Desktop Folder")

                if alert.runModal() == .alertSecondButtonReturn {
                    // Open Desktop folder
                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                }
            } else {
                let content = UNMutableNotificationContent()
                content.title = "Screenshot Saved for Terminal"
                content.body = "📁 \(fileName) → File path copied to clipboard"
                content.sound = UNNotificationSound.default

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("⚠️ Failed to deliver notification: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Poll clipboard until it updates or timeout
    /// - Parameters:
    ///   - initialChangeCount: The changeCount before screenshot
    ///   - timeout: Maximum time to wait (seconds)
    ///   - completion: Called with true if clipboard updated, false if timeout
    private func waitForClipboardUpdate(
        initialChangeCount: Int,
        timeout: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        let startTime = Date()
        let pollInterval: TimeInterval = 0.05  // Poll every 50ms

        func poll() {
            let pasteboard = NSPasteboard.general
            let currentChangeCount = pasteboard.changeCount

            // Success: Clipboard has been updated
            if currentChangeCount > initialChangeCount {
                let elapsed = Date().timeIntervalSince(startTime)
                print("✅ Clipboard updated after \(String(format: "%.3f", elapsed))s")
                completion(true)
                return
            }

            // Timeout: Clipboard didn't update in time
            if Date().timeIntervalSince(startTime) >= timeout {
                print("⚠️ Clipboard polling timeout after \(timeout)s")
                completion(false)
                return
            }

            // Continue polling
            DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
                poll()
            }
        }

        // Start polling after initial delay
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
            poll()
        }
    }

    /// Simulate Command+V keypress to paste clipboard content
    /// Returns true if paste events were posted successfully, false otherwise
    @discardableResult
    private func simulatePaste() -> Bool {
        // CRITICAL: Check Accessibility permission first
        guard checkAccessibilityPermission() else {
            print("⚠️ Auto-paste failed: No Accessibility permission")
            showAccessibilityPermissionAlert()
            return false
        }

        // DEBUG: Check which app will receive the paste
        print("🔍 Auto-paste target check:")
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            print("   Frontmost app: \(frontmost.localizedName ?? "Unknown")")
            print("   Bundle ID: \(frontmost.bundleIdentifier ?? "Unknown")")
            if frontmost.bundleIdentifier == Bundle.main.bundleIdentifier {
                print("   ⚠️ WARNING: We are frontmost! Cmd+V will paste to ourselves, not target app!")
            }
        } else {
            print("   ⚠️ No frontmost app detected")
        }

        // Create all keyboard events with error checking
        guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false) else {
            print("⚠️ Auto-paste failed: Could not create CGEvents")
            showPasteFailureNotification("Failed to create keyboard events. Please paste manually with ⌘V.")
            return false
        }

        // Set command modifier flag on key events
        cmdDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        // cmdUp doesn't need modifier (key is being released)

        // Post the keyboard events to simulate Command+V
        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        print("✅ Auto-paste keyboard events posted successfully")
        return true
    }

    // MARK: - Universal Paste Modes

    /// Copy image to clipboard for pasting (for chat apps, browsers, etc.)
    /// - Parameter imagePath: Path to the screenshot image file
    private func copyImageToClipboard(from imagePath: String) -> Bool {
        guard let image = NSImage(contentsOfFile: imagePath) else {
            print("⚠️ Failed to load image from: \(imagePath)")
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write image data in multiple formats for maximum compatibility
        var success = false

        // Try PNG data first (most compatible)
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            success = pasteboard.setData(pngData, forType: .png)
            print("✅ PNG data copied to clipboard")
        }

        // Also add TIFF for apps that prefer it
        if let tiffData = image.tiffRepresentation {
            _ = pasteboard.setData(tiffData, forType: .tiff)
        }

        // Add file URL for apps that accept file drops
        let fileURL = URL(fileURLWithPath: imagePath)
        pasteboard.writeObjects([fileURL as NSURL])

        return success
    }

    /// Capture and paste with specified paste mode
    /// - Parameters:
    ///   - targetWindow: Window to capture
    ///   - pasteMode: How to paste (file path, image, or auto)
    ///   - sourceWindow: The source window (for CWD detection if file path mode)
    func captureWithPasteMode(
        _ targetWindow: WindowInfo,
        pasteMode: PasteMode,
        sourceWindow: WindowInfo?
    ) {
        // Determine actual paste mode if auto
        let actualPasteMode: PasteMode
        if pasteMode == .auto {
            if let source = sourceWindow {
                let category = AppRegistry.category(for: source)
                actualPasteMode = category.preferredPasteMode
            } else {
                actualPasteMode = sourceAppSupportsFilePath() ? .filePath : .image
            }
        } else {
            actualPasteMode = pasteMode
        }

        print("📸 Capture with paste mode: \(actualPasteMode.displayName)")

        switch actualPasteMode {
        case .filePath:
            captureAndPasteFilePath(targetWindow, sourceWindow: sourceWindow)
        case .image:
            captureAndPasteImage(targetWindow)
        case .auto:
            // Should not reach here, but default to image
            captureAndPasteImage(targetWindow)
        }
    }

    /// Capture target window and paste as IMAGE (for chat apps, browsers, etc.)
    private func captureAndPasteImage(_ targetWindow: WindowInfo) {
        // Generate temp filename
        let fileName = "Screenshot-\(dateFormatter.string(from: Date())).png"
        let tempDir = FileManager.default.temporaryDirectory
        let tempPath = tempDir.appendingPathComponent(fileName)

        var arguments = ["-x", "-T", "0", tempPath.path]

        // Validate target window still exists
        if WindowManager.shared.isWindowValid(targetWindow) {
            arguments.insert("-l\(targetWindow.id)", at: 0)
            arguments.append("-o") // Disable shadow
            print("🎯 Capturing for image paste: \(targetWindow.displayName)")
        } else {
            print("⚠️ Target window no longer exists, capturing full screen")
        }

        runScreencapture(arguments: arguments) {
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard FileManager.default.fileExists(atPath: tempPath.path) else {
                        print("⚠️ Screenshot save failed")
                        self.showPasteFailureNotification("Failed to capture screenshot.")
                        return
                    }

                    // Copy image to clipboard (not file path)
                    guard self.copyImageToClipboard(from: tempPath.path) else {
                        print("⚠️ Failed to copy image to clipboard")
                        self.showPasteFailureNotification("Failed to copy image to clipboard.")
                        return
                    }

                    print("✅ Image copied to clipboard")

                    // Auto-paste the image
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.simulatePaste()
                        print("✅ Image paste triggered")

                        // Clean up temp file after a delay
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                            try? FileManager.default.removeItem(at: tempPath)
                        }
                    }
                }
            }
        }
    }

    /// Capture target window and paste as FILE PATH (for terminals, IDEs)
    private func captureAndPasteFilePath(_ targetWindow: WindowInfo, sourceWindow: WindowInfo?) {
        // Get the source app for CWD detection
        let currentFrontmost = NSWorkspace.shared.frontmostApplication
        let sourceApp: NSRunningApplication?

        if currentFrontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            sourceApp = WindowManager.shared.getPreviousFrontmostApp()
        } else {
            sourceApp = currentFrontmost
        }

        // Generate filename
        let fileName = "Screenshot-\(dateFormatter.string(from: Date())).png"

        // Determine save path
        let savePath: URL
        if let app = sourceApp, let cwd = getCurrentWorkingDirectory(for: app) {
            let cwdURL = URL(filePath: cwd)
            let screenshotsDir = cwdURL.appendingPathComponent("FloatyClipshot/tmp")

            do {
                try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
                savePath = screenshotsDir.appendingPathComponent(fileName)
            } catch {
                print("⚠️ Failed to create screenshots directory: \(error)")
                savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")
            }
        } else {
            savePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")
        }

        var arguments = ["-x", "-T", "0", savePath.path]

        if WindowManager.shared.isWindowValid(targetWindow) {
            arguments.insert("-l\(targetWindow.id)", at: 0)
            arguments.append("-o") // Disable shadow
            print("🎯 Capturing for file path paste: \(targetWindow.displayName)")
        }

        runScreencapture(arguments: arguments) {
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    guard FileManager.default.fileExists(atPath: savePath.path) else {
                        print("⚠️ Screenshot save failed")
                        self.showPasteFailureNotification("Failed to save screenshot.")
                        return
                    }

                    // Copy file path to clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(savePath.path, forType: .string)

                    print("✅ File path copied: \(savePath.path)")

                    // Auto-paste
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.simulatePaste()
                        print("✅ File path paste triggered")
                    }
                }
            }
        }
    }

    /// Show notification/alert when paste operation fails
    private func showPasteFailureNotification(_ message: String) {
        DispatchQueue.main.async {
            // Check if app is in foreground to avoid deadlock
            if NSApplication.shared.isActive {
                let alert = NSAlert()
                alert.messageText = "Auto-Paste Failed"
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else {
                // App in background - use notification
                let content = UNMutableNotificationContent()
                content.title = "Auto-Paste Failed"
                content.body = message
                content.sound = UNNotificationSound.default

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("⚠️ Failed to deliver notification: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Let user select a region and copy to clipboard
    func captureRegion() {
        var arguments = ["-i", "-c", "-T", "0"]  // -T 0 disables thumbnail for faster capture

        // Note: Region selection with window-specific capture isn't directly supported
        // If a window is selected, we'll capture the full window instead
        if let window = WindowManager.shared.selectedWindow {
            arguments = ["-x", "-c", "-T", "0", "-o", "-l\(window.id)"]  // -T 0 -o for speed
        }

        runScreencapture(arguments: arguments) {
            // Give the clipboard a moment to update, then trigger clipboard manager
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // The ClipboardManager will automatically detect this change
            }
        }
    }

    /// Capture selected window or full screen and save to file
    func captureFullScreenToFile() {
        let fileName = "Screenshot-\(dateFormatter.string(from: Date())).png"
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")

        var arguments = ["-x", "-T", "0", desktopPath.path]  // -T 0 disables thumbnail for faster capture

        // If a window is selected, capture only that window
        if let window = WindowManager.shared.selectedWindow {
            arguments.insert("-l\(window.id)", at: 0)
            arguments.append("-o") // Disable shadow
        }

        runScreencapture(arguments: arguments)
    }

    /// Capture region and save to file
    func captureRegionToFile() {
        let fileName = "Screenshot-\(dateFormatter.string(from: Date())).png"
        let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(fileName)")

        var arguments = ["-i", "-T", "0", desktopPath.path]  // -T 0 disables thumbnail for faster capture

        // If a window is selected, capture the full window instead of region
        if let window = WindowManager.shared.selectedWindow {
            arguments = ["-x", "-T", "0", "-o", desktopPath.path, "-l\(window.id)"]  // -T 0 -o for speed
        }

        runScreencapture(arguments: arguments)
    }

    /// Date formatter for screenshot filenames
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss-SSS"  // Added milliseconds to prevent collisions
        return formatter
    }()

    /// Runs the macOS `screencapture` tool
    private func runScreencapture(arguments: [String], timeout: TimeInterval = 5.0, completion: (() -> Void)? = nil) {
        let task = Process()

        // On most macOS systems, screencapture is here:
        // If this path fails, run `which screencapture` in Terminal
        // and update the path accordingly.
        task.executableURL = URL(filePath: "/usr/sbin/screencapture")
        task.arguments = arguments

        // Set quality of service for better priority
        task.qualityOfService = .userInteractive

        // Add timeout protection
        var timeoutTimer: DispatchWorkItem?
        timeoutTimer = DispatchWorkItem {
            if task.isRunning {
                task.terminate()
                print("⚠️ Screenshot timed out after \(timeout)s")
            }
        }
        
        if let timer = timeoutTimer {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timer)
        }

        // Add completion/termination handler
        task.terminationHandler = { [weak task] process in
            // Move logic to a capture-safe block
            DispatchQueue.main.async {
                // The timer will be cancelled by the local scope or a separate reference if needed
                // but we should avoid capturing the DispatchWorkItem directly in a way that causes warnings
                if process.terminationStatus == 0 {
                    completion?()
                } else {
                    print("❌ Screenshot failed with status: \(process.terminationStatus)")
                }
            }
        }

        // Always run async (never block UI)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try task.run()
            } catch {
                print("Failed to run screencapture: \(error)")
                // Optionally show an alert to the user
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Screenshot Failed"
                    alert.informativeText = "Could not capture screenshot: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    /// Show alert when selected window is closed
    private func showWindowClosedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Target Window Closed"
            alert.informativeText = "The selected window no longer exists. Capturing full screen instead. Right-click the button to select a new window."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
