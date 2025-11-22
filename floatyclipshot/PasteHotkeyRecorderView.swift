//
//  PasteHotkeyRecorderView.swift
//  floatyclipshot
//
//  Created for capture & paste hotkey customization
//

import SwiftUI
import AppKit
import Carbon

struct PasteHotkeyRecorderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var hotkeyManager = HotkeyManager.shared

    @State private var isRecording = false
    @State private var recordedKeyCode: UInt32?
    @State private var recordedModifiers: UInt32 = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Customize Capture & Paste Hotkey")
                .font(.title2)
                .bold()

            Text("Press your desired key combination")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Recording area
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isRecording ? Color.blue : Color.gray, lineWidth: 2)
                    )

                VStack(spacing: 8) {
                    if isRecording {
                        Text("Recording...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Text(displayString)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isRecording ? .primary : .secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                startRecording()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                if recordedKeyCode != nil {
                    Button("Clear") {
                        recordedKeyCode = nil
                        recordedModifiers = 0
                        errorMessage = nil
                    }
                }

                Button("Save") {
                    saveHotkey()
                }
                .keyboardShortcut(.return)
                .disabled(recordedKeyCode == nil)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(PasteHotkeyRecorderBackground(isRecording: $isRecording,
                                              recordedKeyCode: $recordedKeyCode,
                                              recordedModifiers: $recordedModifiers,
                                              errorMessage: $errorMessage))
    }

    private var displayString: String {
        if let keyCode = recordedKeyCode {
            return formatHotkey(keyCode: keyCode, modifiers: recordedModifiers)
        } else if isRecording {
            return "Press keys..."
        } else {
            return hotkeyManager.pasteHotkeyDisplayString
        }
    }

    private func startRecording() {
        isRecording = true
        errorMessage = nil
    }

    private func saveHotkey() {
        guard let keyCode = recordedKeyCode else { return }

        // Validate: must have at least one modifier key
        if recordedModifiers == 0 {
            errorMessage = "Hotkey must include at least one modifier key (⌘, ⇧, ⌥, or ⌃)"
            return
        }

        // Update the paste hotkey manager
        hotkeyManager.updatePasteHotkey(keyCode: keyCode, modifiers: recordedModifiers)
        dismiss()
    }

    private func formatHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
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

// Background view that captures keyboard events
struct PasteHotkeyRecorderBackground: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var recordedKeyCode: UInt32?
    @Binding var recordedModifiers: UInt32
    @Binding var errorMessage: String?

    func makeNSView(context: Context) -> NSView {
        let view = PasteKeyCaptureView()
        view.onKeyPressed = { keyCode, modifiers in
            recordedKeyCode = keyCode
            recordedModifiers = modifiers
            isRecording = false
            errorMessage = nil
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let captureView = nsView as? PasteKeyCaptureView {
            captureView.isRecording = isRecording
        }
    }
}

// Custom NSView to capture key events
class PasteKeyCaptureView: NSView {
    var isRecording = false
    var onKeyPressed: ((UInt32, UInt32) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = UInt32(event.keyCode)
        let modifierFlags = event.modifierFlags

        // Convert NSEvent.ModifierFlags to Carbon modifiers
        var carbonModifiers: UInt32 = 0

        if modifierFlags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if modifierFlags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if modifierFlags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if modifierFlags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }

        onKeyPressed?(keyCode, carbonModifiers)
    }

    override func flagsChanged(with event: NSEvent) {
        // Handle modifier-only presses
        super.flagsChanged(with: event)
    }
}

#Preview {
    PasteHotkeyRecorderView()
        .frame(width: 400, height: 300)
}
