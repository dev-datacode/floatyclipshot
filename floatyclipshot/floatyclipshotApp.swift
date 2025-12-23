import SwiftUI
import AppKit
import UserNotifications // For notifications

@main
struct FloatingScreenshotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We don't need a main window scene, just settings (optional)
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    private var positionSaveTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification authorization on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("⚠️ Notification permission denied: \(error.localizedDescription)")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
        
        // CRITICAL: Show privacy warning BEFORE creating any windows
        // This prevents race condition where user could interact with app before seeing warning
        if !SettingsManager.shared.hasShownPrivacyWarning {
            showPrivacyWarningSync()
        }

        // Initialize hotkey manager
        // It starts disabled by default, user can enable via context menu
        _ = HotkeyManager.shared

        // Initialize tag manager (starts displaying tags on windows)
        _ = TagManager.shared

        let contentView = FloatingButtonView()

        // Load saved position and validate it's on-screen
        let savedPosition = SettingsManager.shared.loadButtonPosition() ?? CGPoint(x: 100, y: 100)
        let validatedPosition = validateButtonPosition(savedPosition)

        // Compact window for the button (50px button + 8px padding on each side = 66px)
        window = NSWindow(
            contentRect: NSRect(x: validatedPosition.x, y: validatedPosition.y, width: 66, height: 66),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating      // Always on top of normal windows
        window.collectionBehavior = [
            .canJoinAllSpaces,        // Show on all Spaces
            .fullScreenAuxiliary      // Also in full-screen apps
        ]
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        window.contentView = hostingView
        window.delegate = self  // Set delegate to receive windowDidMove
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save clipboard history before quit
        ClipboardManager.shared.saveHistoryImmediately()
        // Save window tags before quit
        TagManager.shared.saveTagsImmediately()
    }

    // MARK: - Privacy Warning

    /// Show privacy warning synchronously BEFORE app starts
    /// Prevents race condition where user could use app before seeing warning
    private func showPrivacyWarningSync() {
        let alert = NSAlert()
        alert.messageText = "Privacy & Data Storage Notice"
        alert.informativeText = """
        FloatyClipshot stores clipboard history and notes UNENCRYPTED on your disk:

        📁 Storage Location:
        ~/Library/Application Support/FloatyClipshot/

        ⚠️ What Gets Stored:
        • All copied text (including passwords, API keys, tokens)
        • All copied images (including screenshots with sensitive info)
        • All quick notes you create
        • 2FA codes, credit card numbers, private messages

        🔓 Security Risk:
        Anyone with access to your Mac can read this data. It is NOT encrypted.

        💡 Recommendations:
        • Use "Pause Monitoring" before copying sensitive data
        • Regularly clear old clipboard history
        • Be mindful of what you copy
        • Consider using password managers instead

        By clicking "I Understand", you acknowledge these risks.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "I Understand")
        alert.addButton(withTitle: "Quit App")

        let response = alert.runModal()

        if response == .alertSecondButtonReturn {
            // User clicked "Quit App"
            print("User declined privacy terms, quitting app")
            NSApplication.shared.terminate(nil)
        } else {
            // User clicked "I Understand"
            SettingsManager.shared.setPrivacyWarningShown()
            print("✅ User acknowledged privacy warning")
        }
    }

    deinit {
        // Clean up timers to prevent memory leak
        positionSaveTimer?.invalidate()
        positionSaveTimer = nil
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // Debounce saves to prevent disk spam while dragging
        positionSaveTimer?.invalidate()
        positionSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                SettingsManager.shared.saveButtonPosition(window.frame.origin)
            }
        }
    }

    // MARK: - Position Validation

    /// Validates that button position is visible on at least one screen
    /// Returns default position if off-screen (e.g., after monitor disconnection)
    private func validateButtonPosition(_ position: CGPoint) -> CGPoint {
        let buttonSize = CGSize(width: 66, height: 66)
        let buttonFrame = CGRect(origin: position, size: buttonSize)

        // Check if button is visible on any screen
        for screen in NSScreen.screens {
            // Check if at least center of button is on this screen
            let buttonCenter = CGPoint(x: position.x + buttonSize.width / 2,
                                      y: position.y + buttonSize.height / 2)

            if screen.frame.contains(buttonCenter) {
                return position  // Valid position
            }
        }

        // Button is off-screen → use default position on main screen
        print("⚠️ Button position \(position) is off-screen, using default")

        // Place in top-right corner of main screen with some padding
        if let mainScreen = NSScreen.main {
            let screenFrame = mainScreen.visibleFrame
            return CGPoint(x: screenFrame.maxX - buttonSize.width - 20,
                          y: screenFrame.maxY - buttonSize.height - 20)
        }

        // Fallback to simple default
        return CGPoint(x: 100, y: 100)
    }
}
