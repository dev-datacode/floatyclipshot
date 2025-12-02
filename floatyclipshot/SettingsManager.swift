//
//  SettingsManager.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import Foundation
import SwiftUI
import Carbon

/// Storage limit options for clipboard history
enum StorageLimit: Int64, Codable, CaseIterable {
    case limit100MB = 104_857_600      // 100 MB
    case limit250MB = 262_144_000      // 250 MB
    case limit500MB = 524_288_000      // 500 MB (default)
    case limit1GB = 1_073_741_824      // 1 GB
    case limit2GB = 2_147_483_648      // 2 GB
    case unlimited = -1                 // No limit

    var displayName: String {
        switch self {
        case .limit100MB: return "100 MB"
        case .limit250MB: return "250 MB"
        case .limit500MB: return "500 MB"
        case .limit1GB: return "1 GB"
        case .limit2GB: return "2 GB"
        case .unlimited: return "Unlimited"
        }
    }

    var bytes: Int64 {
        return self.rawValue
    }

    var isUnlimited: Bool {
        return self == .unlimited
    }
}

final class SettingsManager {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // Keys for UserDefaults
    private enum Keys {
        // Capture hotkey
        static let hotkeyEnabled = "hotkeyEnabled"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        // Paste hotkey
        static let pasteHotkeyEnabled = "pasteHotkeyEnabled"
        static let pasteHotkeyKeyCode = "pasteHotkeyKeyCode"
        static let pasteHotkeyModifiers = "pasteHotkeyModifiers"
        // Window selection
        static let selectedWindowID = "selectedWindowID"
        static let selectedWindowName = "selectedWindowName"
        static let selectedWindowOwner = "selectedWindowOwner"
        // UI
        static let buttonPositionX = "buttonPositionX"
        static let buttonPositionY = "buttonPositionY"
        // Storage
        static let storageLimit = "storageLimit"
        // Privacy
        static let privacyWarningShown = "privacyWarningShown"
    }

    private init() {}

    // MARK: - Capture Hotkey Settings

    var hotkeyEnabled: Bool {
        get {
            // Check if value has been set before
            // If never set, default to ENABLED for better first-time user experience
            if defaults.object(forKey: Keys.hotkeyEnabled) == nil {
                return true  // ✅ Default to ENABLED for new users
            }
            return defaults.bool(forKey: Keys.hotkeyEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.hotkeyEnabled) }
    }

    var hotkeyKeyCode: UInt32 {
        get {
            let value = defaults.integer(forKey: Keys.hotkeyKeyCode)
            return value == 0 ? 100 : UInt32(value) // Default to F8 (100)
        }
        set { defaults.set(Int(newValue), forKey: Keys.hotkeyKeyCode) }
    }

    var hotkeyModifiers: UInt32 {
        get {
            let value = defaults.integer(forKey: Keys.hotkeyModifiers)
            return value == 0 ? UInt32(cmdKey | shiftKey) : UInt32(value) // Default to Cmd+Shift
        }
        set { defaults.set(Int(newValue), forKey: Keys.hotkeyModifiers) }
    }

    // MARK: - Paste Hotkey Settings

    var pasteHotkeyEnabled: Bool {
        get {
            // Check if value has been set before
            // If never set, default to ENABLED for better first-time user experience
            if defaults.object(forKey: Keys.pasteHotkeyEnabled) == nil {
                return true  // ✅ Default to ENABLED for new users
            }
            return defaults.bool(forKey: Keys.pasteHotkeyEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.pasteHotkeyEnabled) }
    }

    var pasteHotkeyKeyCode: UInt32 {
        get {
            let value = defaults.integer(forKey: Keys.pasteHotkeyKeyCode)
            return value == 0 ? 109 : UInt32(value) // Default to F10 (109)
        }
        set { defaults.set(Int(newValue), forKey: Keys.pasteHotkeyKeyCode) }
    }

    var pasteHotkeyModifiers: UInt32 {
        get {
            let value = defaults.integer(forKey: Keys.pasteHotkeyModifiers)
            return value == 0 ? UInt32(cmdKey | shiftKey) : UInt32(value) // Default to Cmd+Shift
        }
        set { defaults.set(Int(newValue), forKey: Keys.pasteHotkeyModifiers) }
    }

    // MARK: - Window Selection Settings

    var selectedWindowID: Int? {
        get {
            let value = defaults.integer(forKey: Keys.selectedWindowID)
            return value == 0 ? nil : value
        }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.selectedWindowID)
            } else {
                defaults.removeObject(forKey: Keys.selectedWindowID)
            }
        }
    }

    var selectedWindowName: String? {
        get { defaults.string(forKey: Keys.selectedWindowName) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.selectedWindowName)
            } else {
                defaults.removeObject(forKey: Keys.selectedWindowName)
            }
        }
    }

    var selectedWindowOwner: String? {
        get { defaults.string(forKey: Keys.selectedWindowOwner) }
        set {
            if let value = newValue {
                defaults.set(value, forKey: Keys.selectedWindowOwner)
            } else {
                defaults.removeObject(forKey: Keys.selectedWindowOwner)
            }
        }
    }

    // MARK: - Button Position

    var buttonPosition: CGPoint? {
        get {
            let x = defaults.double(forKey: Keys.buttonPositionX)
            let y = defaults.double(forKey: Keys.buttonPositionY)
            // If both are 0, assume no saved position
            return (x == 0 && y == 0) ? nil : CGPoint(x: x, y: y)
        }
        set {
            if let point = newValue {
                defaults.set(point.x, forKey: Keys.buttonPositionX)
                defaults.set(point.y, forKey: Keys.buttonPositionY)
            } else {
                defaults.removeObject(forKey: Keys.buttonPositionX)
                defaults.removeObject(forKey: Keys.buttonPositionY)
            }
        }
    }

    // MARK: - Storage Settings

    var storageLimit: StorageLimit {
        get {
            let rawValue = defaults.object(forKey: Keys.storageLimit) as? Int64 ?? StorageLimit.limit500MB.rawValue
            return StorageLimit(rawValue: rawValue) ?? .limit500MB
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.storageLimit)
        }
    }

    func calculateTargetSize(for limit: StorageLimit) -> Int64 {
        // When cleanup is triggered, reduce to 70% of limit (freeing 30% space)
        guard !limit.isUnlimited else { return Int64.max }
        return Int64(Double(limit.bytes) * 0.7)
    }

    // MARK: - Save Methods

    func saveHotkeySettings(enabled: Bool, keyCode: UInt32, modifiers: UInt32) {
        hotkeyEnabled = enabled
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
    }

    func savePasteHotkeySettings(enabled: Bool, keyCode: UInt32, modifiers: UInt32) {
        pasteHotkeyEnabled = enabled
        pasteHotkeyKeyCode = keyCode
        pasteHotkeyModifiers = modifiers
    }

    func saveSelectedWindow(_ window: WindowInfo?) {
        if let window = window {
            selectedWindowID = window.id
            selectedWindowName = window.name
            selectedWindowOwner = window.ownerName
        } else {
            selectedWindowID = nil
            selectedWindowName = nil
            selectedWindowOwner = nil
        }
    }

    func saveButtonPosition(_ position: CGPoint) {
        buttonPosition = position
    }

    // MARK: - Load Methods

    func loadHotkeySettings() -> (enabled: Bool, keyCode: UInt32, modifiers: UInt32) {
        return (hotkeyEnabled, hotkeyKeyCode, hotkeyModifiers)
    }

    func loadPasteHotkeySettings() -> (enabled: Bool, keyCode: UInt32, modifiers: UInt32) {
        return (pasteHotkeyEnabled, pasteHotkeyKeyCode, pasteHotkeyModifiers)
    }

    func loadSelectedWindow() -> WindowInfo? {
        guard let windowID = selectedWindowID,
              let ownerName = selectedWindowOwner else {
            return nil
        }

        let windowName = selectedWindowName ?? ""

        return WindowInfo(
            id: windowID,
            name: windowName,
            ownerName: ownerName,
            ownerPID: 0, // PID is not persisted, will be updated when window list is refreshed
            bounds: .zero // Bounds will be updated when window list is refreshed
        )
    }

    func loadButtonPosition() -> CGPoint? {
        return buttonPosition
    }

    // MARK: - Privacy Warning

    var hasShownPrivacyWarning: Bool {
        return defaults.bool(forKey: Keys.privacyWarningShown)
    }

    func setPrivacyWarningShown() {
        defaults.set(true, forKey: Keys.privacyWarningShown)
    }

    // MARK: - Reset

    func resetAllSettings() {
        defaults.removeObject(forKey: Keys.hotkeyEnabled)
        defaults.removeObject(forKey: Keys.hotkeyKeyCode)
        defaults.removeObject(forKey: Keys.hotkeyModifiers)
        defaults.removeObject(forKey: Keys.pasteHotkeyEnabled)
        defaults.removeObject(forKey: Keys.pasteHotkeyKeyCode)
        defaults.removeObject(forKey: Keys.pasteHotkeyModifiers)
        defaults.removeObject(forKey: Keys.selectedWindowID)
        defaults.removeObject(forKey: Keys.selectedWindowName)
        defaults.removeObject(forKey: Keys.selectedWindowOwner)
        defaults.removeObject(forKey: Keys.buttonPositionX)
        defaults.removeObject(forKey: Keys.buttonPositionY)
        defaults.removeObject(forKey: Keys.privacyWarningShown)
    }
}
