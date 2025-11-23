import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

final class ScreenshotManager {
    static let shared = ScreenshotManager()

    private init() {}

    // MARK: - Terminal Detection

    /// Get the current working directory of a terminal application
    /// - Parameter app: The running terminal application
    /// - Returns: The current working directory path, or nil if unable to determine
    private func getCurrentWorkingDirectory(for app: NSRunningApplication) -> String? {
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

        // Known terminal app bundle IDs
        let terminalBundleIDs = [
            "com.apple.Terminal",           // Terminal.app
            "com.googlecode.iterm2",        // iTerm2
            "org.alacritty",                // Alacritty
            "net.kovidgoyal.kitty",         // Kitty
            "co.zeit.hyper",                // Hyper
            "dev.warp.Warp-Stable",         // Warp
            "com.github.wez.wezterm",       // WezTerm
            "io.terminus"                   // Terminus
            // Note: VS Code removed - users paste into markdown/comments more than terminal
        ]

        if let bundleID = app.bundleIdentifier {
            let isTerminal = terminalBundleIDs.contains(bundleID)
            print("   Is terminal: \(isTerminal ? "✅ YES" : "❌ NO")")
            return isTerminal
        }

        print("   Is terminal: ❌ NO (no bundle ID)")
        return false
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

Alternative: Use ⌘⇧F8 to capture without auto-paste.
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
                let notification = NSUserNotification()
                notification.title = "Accessibility Permission Required"
                notification.informativeText = "Auto-paste needs Accessibility permission. Check System Preferences → Security & Privacy → Accessibility"
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }

    /// Capture the selected window or full screen and copy to clipboard
    func captureFullScreen() {
        var arguments = ["-x", "-c", "-T", "0"]  // -T 0 disables thumbnail for faster capture

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

    /// Capture the selected window or full screen, copy to clipboard, and auto-paste
    func captureAndPaste() {
        print("📸 captureAndPaste() called")

        // SMART TERMINAL DETECTION: Check if target app is a terminal
        if isFrontmostAppTerminal() {
            print("   ✅ Terminal detected - using file path mode")
            // Terminal detected - save to file and copy path instead
            captureAndPasteToTerminal()
            return
        }

        print("   ℹ️ Non-terminal app - using clipboard mode")
        // Regular app - use clipboard + auto-paste
        var arguments = ["-x", "-c", "-T", "0"]  // -T 0 disables thumbnail for faster capture

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
            let screenshotsDir = cwdURL.appendingPathComponent("tmp/screenshots")

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
                let notification = NSUserNotification()
                notification.title = "Screenshot Saved for Terminal"
                notification.informativeText = "📁 \(fileName) → File path copied to clipboard"
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
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
                let notification = NSUserNotification()
                notification.title = "Auto-Paste Failed"
                notification.informativeText = message
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }

    /// Let user select a region and copy to clipboard
    func captureRegion() {
        var arguments = ["-i", "-c", "-T", "0"]  // -T 0 disables thumbnail for faster capture

        // Note: Region selection with window-specific capture isn't directly supported
        // If a window is selected, we'll capture the full window instead
        if let window = WindowManager.shared.selectedWindow {
            arguments = ["-x", "-c", "-T", "0", "-l\(window.id)"]  // -T 0 disables thumbnail for faster capture
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
            arguments = ["-x", "-T", "0", desktopPath.path, "-l\(window.id)"]  // -T 0 disables thumbnail for faster capture
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
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutTimer!)

        // Add completion/termination handler
        task.terminationHandler = { process in
            // Cancel timeout timer since process completed
            timeoutTimer?.cancel()

            DispatchQueue.main.async {
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
