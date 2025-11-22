//
//  HotkeyManager.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import Foundation
import AppKit
import Carbon
import SwiftUI
import Combine

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    // MARK: - Capture Hotkey (Default: Cmd+Shift+F8)
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                registerHotkey()
            } else {
                unregisterHotkey()
            }
            // Save to settings
            SettingsManager.shared.hotkeyEnabled = isEnabled
        }
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    // Default: Command + Shift + F8
    @Published var keyCode: UInt32 = 100 // F8 key code
    @Published var modifiers: UInt32 = UInt32(cmdKey | shiftKey) // Command + Shift

    // MARK: - Capture & Paste Hotkey (Default: Cmd+Shift+F10)
    @Published var pasteHotkeyEnabled: Bool = false {
        didSet {
            if pasteHotkeyEnabled {
                registerPasteHotkey()
            } else {
                unregisterPasteHotkey()
            }
            // Save to settings
            SettingsManager.shared.pasteHotkeyEnabled = pasteHotkeyEnabled
        }
    }

    private var pasteHotKeyRef: EventHotKeyRef?
    private var pasteEventHandler: EventHandlerRef?

    // Default: Command + Shift + F10
    @Published var pasteKeyCode: UInt32 = 109 // F10 key code
    @Published var pasteModifiers: UInt32 = UInt32(cmdKey | shiftKey) // Command + Shift

    private init() {
        // Load saved settings for capture hotkey
        let settings = SettingsManager.shared.loadHotkeySettings()
        self.isEnabled = settings.enabled
        self.keyCode = settings.keyCode
        self.modifiers = settings.modifiers

        // Load saved settings for paste hotkey
        let pasteSettings = SettingsManager.shared.loadPasteHotkeySettings()
        self.pasteHotkeyEnabled = pasteSettings.enabled
        self.pasteKeyCode = pasteSettings.keyCode
        self.pasteModifiers = pasteSettings.modifiers

        // Register hotkeys if enabled
        if isEnabled {
            registerHotkey()
        }
        if pasteHotkeyEnabled {
            registerPasteHotkey()
        }
    }

    /// Update capture hotkey to a new key combination
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers

        // Save to settings
        SettingsManager.shared.saveHotkeySettings(
            enabled: isEnabled,
            keyCode: keyCode,
            modifiers: modifiers
        )

        // Re-register if hotkey is enabled
        if isEnabled {
            registerHotkey()
        }
    }

    /// Update paste hotkey to a new key combination
    func updatePasteHotkey(keyCode: UInt32, modifiers: UInt32) {
        self.pasteKeyCode = keyCode
        self.pasteModifiers = modifiers

        // Save to settings
        SettingsManager.shared.savePasteHotkeySettings(
            enabled: pasteHotkeyEnabled,
            keyCode: keyCode,
            modifiers: modifiers
        )

        // Re-register if hotkey is enabled
        if pasteHotkeyEnabled {
            registerPasteHotkey()
        }
    }

    func registerHotkey() {
        // Unregister existing hotkey first
        unregisterHotkey()

        // Create event type
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install event handler
        _ = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // Capture screenshot when hotkey is pressed
            DispatchQueue.main.async {
                // Show visual feedback
                NotificationCenter.default.post(name: NSNotification.Name("TriggerCaptureAnimation"), object: nil)

                // Capture screenshot
                ScreenshotManager.shared.captureFullScreen()
            }
            return noErr
        }, 1, &eventType, nil, &eventHandler)

        // Register hotkey
        let hotKeyID = EventHotKeyID(signature: fourCharCode("FLCS"), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        if status != noErr {
            // Clean up event handler if hotkey registration failed
            if let eventHandler = eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }

            print("⚠️ Failed to register hotkey: \(status)")

            // Show user-facing error (safe alert pattern to avoid deadlock)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // CRITICAL: Check if app is in foreground to avoid deadlock
                if NSApplication.shared.isActive {
                    // App in foreground - safe to show modal alert
                    let alert = NSAlert()
                    alert.messageText = "Hotkey Registration Failed"
                    alert.informativeText = "Could not register \(self.hotkeyDisplayString). This hotkey may be in use by another application. Please choose a different key combination."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                } else {
                    // App in background - use notification instead to avoid deadlock
                    let notification = NSUserNotification()
                    notification.title = "Hotkey Registration Failed"
                    notification.informativeText = "Could not register \(self.hotkeyDisplayString). Hotkey may be in use by another application."
                    notification.soundName = NSUserNotificationDefaultSoundName
                    NSUserNotificationCenter.default.deliver(notification)
                }

                // Disable hotkey since it failed
                self.isEnabled = false
            }
        } else {
            print("✅ Hotkey registered successfully: \(hotkeyDisplayString)")
        }
    }

    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    // MARK: - Paste Hotkey Registration

    func registerPasteHotkey() {
        // Unregister existing paste hotkey first
        unregisterPasteHotkey()

        // Create event type
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install event handler for paste hotkey
        _ = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            // Get the hotkey ID to determine which hotkey was pressed
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr && hotKeyID.id == 2 {
                // Paste hotkey was pressed
                DispatchQueue.main.async {
                    // Show visual feedback
                    NotificationCenter.default.post(name: NSNotification.Name("TriggerCaptureAnimation"), object: nil)

                    // Capture screenshot and auto-paste
                    ScreenshotManager.shared.captureAndPaste()
                }
            }
            return noErr
        }, 1, &eventType, nil, &pasteEventHandler)

        // Register paste hotkey with ID = 2
        let hotKeyID = EventHotKeyID(signature: fourCharCode("FLCP"), id: 2)
        let status = RegisterEventHotKey(pasteKeyCode, pasteModifiers, hotKeyID, GetApplicationEventTarget(), 0, &pasteHotKeyRef)

        if status != noErr {
            // Clean up event handler if hotkey registration failed
            if let eventHandler = pasteEventHandler {
                RemoveEventHandler(eventHandler)
                self.pasteEventHandler = nil
            }

            print("⚠️ Failed to register paste hotkey: \(status)")

            // Show user-facing error (safe alert pattern to avoid deadlock)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // CRITICAL: Check if app is in foreground to avoid deadlock
                if NSApplication.shared.isActive {
                    // App in foreground - safe to show modal alert
                    let alert = NSAlert()
                    alert.messageText = "Paste Hotkey Registration Failed"
                    alert.informativeText = "Could not register \(self.pasteHotkeyDisplayString). This hotkey may be in use by another application. Please choose a different key combination."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                } else {
                    // App in background - use notification instead to avoid deadlock
                    let notification = NSUserNotification()
                    notification.title = "Paste Hotkey Registration Failed"
                    notification.informativeText = "Could not register \(self.pasteHotkeyDisplayString). Hotkey may be in use by another application."
                    notification.soundName = NSUserNotificationDefaultSoundName
                    NSUserNotificationCenter.default.deliver(notification)
                }

                // Disable hotkey since it failed
                self.pasteHotkeyEnabled = false
            }
        } else {
            print("✅ Paste hotkey registered successfully: \(pasteHotkeyDisplayString)")
        }
    }

    func unregisterPasteHotkey() {
        if let pasteHotKeyRef = pasteHotKeyRef {
            UnregisterEventHotKey(pasteHotKeyRef)
            self.pasteHotKeyRef = nil
        }

        if let pasteEventHandler = pasteEventHandler {
            RemoveEventHandler(pasteEventHandler)
            self.pasteEventHandler = nil
        }
    }

    // Helper function to convert string to FourCharCode
    private func fourCharCode(_ string: String) -> FourCharCode {
        assert(string.count == 4, "String must be exactly 4 characters")
        var result: FourCharCode = 0
        for char in string.utf8 {
            result = (result << 8) | FourCharCode(char)
        }
        return result
    }

    // Get display string for current capture hotkey
    var hotkeyDisplayString: String {
        var keys: [String] = []

        if modifiers & UInt32(cmdKey) != 0 {
            keys.append("⌘")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            keys.append("⇧")
        }
        if modifiers & UInt32(optionKey) != 0 {
            keys.append("⌥")
        }
        if modifiers & UInt32(controlKey) != 0 {
            keys.append("⌃")
        }

        // Add key name
        keys.append(keyCodeToString(keyCode))

        return keys.joined(separator: " ")
    }

    // Get display string for current paste hotkey
    var pasteHotkeyDisplayString: String {
        var keys: [String] = []

        if pasteModifiers & UInt32(cmdKey) != 0 {
            keys.append("⌘")
        }
        if pasteModifiers & UInt32(shiftKey) != 0 {
            keys.append("⇧")
        }
        if pasteModifiers & UInt32(optionKey) != 0 {
            keys.append("⌥")
        }
        if pasteModifiers & UInt32(controlKey) != 0 {
            keys.append("⌃")
        }

        // Add key name
        keys.append(keyCodeToString(pasteKeyCode))

        return keys.joined(separator: " ")
    }

    // Convert key code to readable string
    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // F-keys
        switch keyCode {
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"

        // Letters
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"

        // Numbers
        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"

        // Special keys
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"

        default: return "Key \(keyCode)"
        }
    }
}
