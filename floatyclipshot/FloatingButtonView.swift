//
//  FloatingButtonView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import Foundation
import SwiftUI
import AppKit

struct FloatingButtonView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var notesManager = NotesManager.shared
    @State private var showCaptureAnimation = false
    @State private var showGlassyFeedback = false
    @State private var showCheckmark = false
    @State private var showHotkeyRecorder = false
    @State private var showPasteHotkeyRecorder = false
    @State private var showStorageSettings = false
    @State private var showQuickNote = false
    @State private var showNotesList = false

    var body: some View {
        ZStack {
            // Main button
            Circle()
                .fill(buttonColor)
                .frame(width: 80, height: 80)
                .shadow(radius: 10)
                .scaleEffect(showCaptureAnimation ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: showCaptureAnimation)

            // Button icon
            Image(systemName: buttonIcon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)

            // Apple-like glassy feedback overlay
            if showGlassyFeedback {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(showGlassyFeedback ? 1.5 : 0.5)
                    .opacity(showGlassyFeedback ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: showGlassyFeedback)
                    .blur(radius: 8)
            }

            // Success checkmark
            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: showCheckmark)
            }
        }
        .padding(12)
        .contentShape(Circle()) // Make entire circle clickable
        .onTapGesture {
            // Primary action: Instant capture!
            performQuickCapture()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerCaptureAnimation"))) { _ in
            // Triggered by keyboard shortcut
            triggerCaptureAnimation()
        }
        .onAppear {
            // FIX: Refresh window list when app launches to populate initial list
            windowManager.refreshWindowList()
        }
        .help(tooltipText)
        .contextMenu {
            // Right-click menu for configuration
            windowSelectionSection

            Divider()

            // Alternative capture options
            if windowManager.selectedWindow == nil {
                Button("Capture Region to Clipboard") {
                    ScreenshotManager.shared.captureRegion()
                }
            }

            Button("Save to Desktop") {
                ScreenshotManager.shared.captureFullScreenToFile()
            }

            Divider()

            // Clipboard memory section
            if !clipboardManager.clipboardHistory.isEmpty {
                Menu("Recent Clipboard") {
                    // Show only the 10 most recent items
                    ForEach(Array(clipboardManager.clipboardHistory.prefix(10).enumerated()), id: \.offset) { index, item in
                        Button(item.displayName) {
                            clipboardManager.pasteItem(item)
                        }
                    }

                    if clipboardManager.clipboardHistory.count > 10 {
                        Divider()
                        Text("\(clipboardManager.clipboardHistory.count - 10) more items...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Button("Clear History") {
                        clipboardManager.clearHistory()
                    }
                }

                Divider()
            }

            // Clipboard monitoring control
            Toggle(isOn: Binding(
                get: { !clipboardManager.isPaused },
                set: { clipboardManager.isPaused = !$0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clipboard Monitoring")
                        .font(.body)
                    Text(clipboardManager.isPaused ? "⏸ Paused" : "▶️ Active")
                        .font(.caption)
                        .foregroundColor(clipboardManager.isPaused ? .orange : .green)
                }
            }

            Divider()

            // Quick Notes section
            Menu("Quick Notes \(notesManager.notes.isEmpty ? "" : "(\(notesManager.notes.count))")") {
                Button(action: { showQuickNote = true }) {
                    Label("Add New Note", systemImage: "plus.circle")
                }

                if !notesManager.notes.isEmpty {
                    Divider()

                    // Show up to 5 most recent notes
                    ForEach(notesManager.notes.prefix(5)) { note in
                        Button(action: {
                            notesManager.copyToClipboard(note)
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                if !note.key.isEmpty {
                                    Text(note.key)
                                        .font(.body)
                                    Text(note.value)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                } else {
                                    Text(note.shortDisplayText)
                                        .font(.body)
                                }
                            }
                        }
                    }

                    if notesManager.notes.count > 5 {
                        Divider()
                        Text("\(notesManager.notes.count - 5) more notes...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Button(action: { showNotesList = true }) {
                        Label("View All Notes", systemImage: "list.bullet")
                    }
                }
            }

            Divider()

            // Storage settings section
            Button(action: {
                showStorageSettings = true
            }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage Settings")
                        .font(.body)
                    Text(storageUsageText)
                        .font(.caption)
                        .foregroundColor(storageUsageColor)
                }
            }

            Divider()

            // Keyboard shortcut section
            Toggle(isOn: $hotkeyManager.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture Hotkey")
                        .font(.body)
                    if hotkeyManager.isEnabled {
                        Text(hotkeyManager.hotkeyDisplayString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button("Change Capture Hotkey...") {
                showHotkeyRecorder = true
            }

            // Paste hotkey section
            Toggle(isOn: $hotkeyManager.pasteHotkeyEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture & Paste Hotkey")
                        .font(.body)
                    if hotkeyManager.pasteHotkeyEnabled {
                        Text(hotkeyManager.pasteHotkeyDisplayString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button("Change Paste Hotkey...") {
                showPasteHotkeyRecorder = true
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .sheet(isPresented: $showHotkeyRecorder) {
            HotkeyRecorderView()
        }
        .sheet(isPresented: $showPasteHotkeyRecorder) {
            PasteHotkeyRecorderView()
        }
        .sheet(isPresented: $showStorageSettings) {
            StorageSettingsView()
        }
        .sheet(isPresented: $showQuickNote) {
            QuickNoteView()
        }
        .sheet(isPresented: $showNotesList) {
            NotesListView()
        }
    }

    // Instant capture with visual feedback
    private func performQuickCapture() {
        triggerCaptureAnimation()
        // Capture to clipboard instantly
        ScreenshotManager.shared.captureFullScreen()
    }

    // Smooth Apple-like capture animation (for keyboard shortcut feedback)
    private func triggerCaptureAnimation() {
        // Button squeeze
        showCaptureAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCaptureAnimation = false
        }

        // Glassy feedback - starts immediately and expands/fades out
        showGlassyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Trigger the expansion/fade animation
            showGlassyFeedback = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Clean up after animation completes
            showGlassyFeedback = false
        }

        // Success checkmark - appears with spring animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showCheckmark = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            showCheckmark = false
        }
    }

    // Window selection section
    @ViewBuilder
    private var windowSelectionSection: some View {
        // Show current selection prominently
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Target:")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(windowManager.selectionDisplayText)
                .font(.body)
                .bold()
        }

        Divider()

        // Window picker with auto-refresh
        Menu("Choose Window Target") {
            // Option to capture full screen
            Button(action: {
                windowManager.clearSelection()
            }) {
                Label("🖥️ Full Screen (All Displays)", systemImage: windowManager.selectedWindow == nil ? "checkmark" : "")
            }

            if !windowManager.availableWindows.isEmpty {
                Divider()

                ForEach(windowManager.availableWindows) { window in
                    Button(action: {
                        windowManager.selectWindow(window)
                    }) {
                        Label(window.displayName, systemImage: windowManager.selectedWindow?.id == window.id ? "checkmark" : "")
                    }
                }
            }
        }
        .onAppear {
            // Auto-refresh when menu opens
            windowManager.refreshWindowList()
        }

        Button("Refresh Window List") {
            windowManager.refreshWindowList()
        }
    }

    // Dynamic button color based on window selection
    private var buttonColor: Color {
        if windowManager.selectedWindow != nil {
            return Color.green.opacity(0.85) // Green = targeted capture ready
        }
        return Color.black.opacity(0.7) // Black = full screen
    }

    // Dynamic icon based on window selection
    private var buttonIcon: String {
        if windowManager.selectedWindow != nil {
            return "scope" // Crosshair = targeted
        }
        return "camera.fill" // Camera = full screen
    }

    // Tooltip text
    private var tooltipText: String {
        if let window = windowManager.selectedWindow {
            return "Click: Capture \(window.displayName)\nRight-click: Options"
        }
        return "Click: Capture Full Screen\nRight-click: Choose Window"
    }

    // Storage usage text and color
    private var storageUsageText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        let usedString = formatter.string(fromByteCount: clipboardManager.totalStorageUsed)

        let limit = SettingsManager.shared.storageLimit
        if limit.isUnlimited {
            return "\(usedString) used • Unlimited"
        } else {
            let limitString = formatter.string(fromByteCount: limit.bytes)
            let percentage = Int((Double(clipboardManager.totalStorageUsed) / Double(limit.bytes)) * 100)
            return "\(usedString) / \(limitString) (\(percentage)%)"
        }
    }

    private var storageUsageColor: Color {
        let limit = SettingsManager.shared.storageLimit
        guard !limit.isUnlimited else { return .secondary }

        let percentage = Double(clipboardManager.totalStorageUsed) / Double(limit.bytes)

        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .secondary
        }
    }
}

#Preview {
    FloatingButtonView()
        .frame(width: 100, height: 100)
        .background(Color.gray.opacity(0.3))
}
