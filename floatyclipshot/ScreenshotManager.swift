import Foundation
import AppKit
import CoreGraphics

final class ScreenshotManager {
    static let shared = ScreenshotManager()

    private init() {}

    /// Capture the selected window or full screen and copy to clipboard
    func captureFullScreen() {
        var arguments = ["-x", "-c"]

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
        var arguments = ["-x", "-c"]

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
            // Wait for clipboard to update, then simulate Command+V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.simulatePaste()
            }
        }
    }

    /// Simulate Command+V keypress to paste clipboard content
    private func simulatePaste() {
        // Create Command key down event
        let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        // Create V key down event with Command modifier
        let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand

        // Create V key up event with Command modifier
        let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        // Create Command key up event
        let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false)

        // Post the events
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)

        print("✅ Auto-pasted screenshot")
    }

    /// Let user select a region and copy to clipboard
    func captureRegion() {
        var arguments = ["-i", "-c"]

        // Note: Region selection with window-specific capture isn't directly supported
        // If a window is selected, we'll capture the full window instead
        if let window = WindowManager.shared.selectedWindow {
            arguments = ["-x", "-c", "-l\(window.id)"]
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

        var arguments = ["-x", desktopPath.path]

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

        var arguments = ["-i", desktopPath.path]

        // If a window is selected, capture the full window instead of region
        if let window = WindowManager.shared.selectedWindow {
            arguments = ["-x", desktopPath.path, "-l\(window.id)"]
        }

        runScreencapture(arguments: arguments)
    }

    /// Date formatter for screenshot filenames
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()

    /// Runs the macOS `screencapture` tool
    private func runScreencapture(arguments: [String], completion: (() -> Void)? = nil) {
        let task = Process()

        // On most macOS systems, screencapture is here:
        // If this path fails, run `which screencapture` in Terminal
        // and update the path accordingly.
        task.executableURL = URL(filePath: "/usr/sbin/screencapture")
        task.arguments = arguments

        // Add completion handler
        if let completion = completion {
            task.terminationHandler = { _ in
                completion()
            }
        }

        do {
            try task.run()
            
            // For synchronous calls (file saves), wait for completion
            if completion == nil {
                task.waitUntilExit()
            }
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
