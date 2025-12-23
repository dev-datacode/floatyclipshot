//
//  SettingsDetailView.swift
//  floatyclipshot
//

import SwiftUI
import AppKit
import Combine

struct SettingsDetailView: View {
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    @State private var showCaptureRecorder = false
    @State private var showPasteRecorder = false
    
    @State private var screenRecordingGranted = false
    @State private var accessibilityGranted = false
    
    @State private var storageLimit = SettingsManager.shared.storageLimit
    @State private var showClearConfirmation = false
    
    // Refresh timer for permissions
    let timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GlassDesign.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Configure FloatyClipshot to your preferences.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .glassAppearAnimation(delay: 0)

                GlassDivider()

                // Keyboard Shortcuts
                GlassCard(tint: .blue.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.md) {
                        Label("Keyboard Shortcuts", systemImage: "keyboard")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Capture to Clipboard")
                                    .fontWeight(.medium)
                                Text("Capture selected window or full screen")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                showCaptureRecorder = true
                            } label: {
                                Text(hotkeyManager.hotkeyDisplayString)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: GlassDesign.Radius.small))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: GlassDesign.Radius.small)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Capture & Paste Path")
                                    .fontWeight(.medium)
                                Text("Capture target and auto-paste into source")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                showPasteRecorder = true
                            } label: {
                                Text(hotkeyManager.pasteHotkeyDisplayString)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: GlassDesign.Radius.small))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: GlassDesign.Radius.small)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .glassAppearAnimation(delay: 0.05)

                // Permissions
                GlassCard(tint: .orange.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.md) {
                        Label("Permissions", systemImage: "lock.shield")
                            .font(.headline)

                        PermissionRow(
                            title: "Screen Recording",
                            description: "Required to capture screenshots",
                            isGranted: screenRecordingGranted
                        ) {
                            screenshotManager.openSystemSettings(for: .screenRecording)
                        }

                        PermissionRow(
                            title: "Accessibility",
                            description: "Required for auto-paste feature",
                            isGranted: accessibilityGranted
                        ) {
                            screenshotManager.openSystemSettings(for: .accessibility)
                        }
                    }
                }
                .glassAppearAnimation(delay: 0.1)

                // Storage Settings
                GlassCard(tint: .purple.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.md) {
                        Label("Storage & History", systemImage: "internaldrive")
                            .font(.headline)
                        
                        HStack {
                            Text("Current Usage")
                                .font(.subheadline)
                            Spacer()
                            Text(formatBytes(clipboardManager.totalStorageUsed))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(usageColor)
                        }
                        
                        GlassProgress(value: usageProgress, color: usageColor)
                        
                        HStack {
                            Text("Storage Limit")
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $storageLimit) {
                                ForEach(StorageLimit.allCases, id: \.self) { limit in
                                    Text(limit.displayName).tag(limit)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .onChange(of: storageLimit) { _, newValue in
                                SettingsManager.shared.storageLimit = newValue
                                if !newValue.isUnlimited && clipboardManager.totalStorageUsed > newValue.bytes {
                                    let targetSize = SettingsManager.shared.calculateTargetSize(for: newValue)
                                    clipboardManager.performManualCleanup(targetSize: targetSize)
                                }
                            }
                        }
                        
                        GlassDivider()
                        
                        HStack {
                            Button(role: .destructive) {
                                showClearConfirmation = true
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Text("\(clipboardManager.clipboardHistory.count) items stored")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .glassAppearAnimation(delay: 0.15)

                // Security & Privacy
                GlassCard(tint: .green.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.md) {
                        HStack {
                            Label("Security & Privacy", systemImage: "lock.shield.fill")
                                .font(.headline)
                            Spacer()
                            EncryptionStatusBadge()
                        }

                        // Private Mode Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Private Mode")
                                    .fontWeight(.medium)
                                Text("Pause clipboard monitoring")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            PrivateModeToggleButton(compact: true)
                        }

                        GlassDivider()

                        // Link to full security settings
                        GlassButton("Advanced Security Settings", icon: "arrow.up.right.square", color: .blue, style: .secondary) {
                            SecuritySettingsWindowController.shared.showWindow()
                        }
                    }
                }
                .glassAppearAnimation(delay: 0.2)

                // About
                GlassCard {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.md - 4) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)

                        HStack {
                            Text("FloatyClipshot")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("Version 1.0")
                                .foregroundStyle(.secondary)
                        }

                        Text("A developer-focused screenshot utility for macOS.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .glassAppearAnimation(delay: 0.25)

                Spacer()
            }
            .padding(GlassDesign.Spacing.lg)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showCaptureRecorder) {
            HotkeyRecorderView()
                .padding()
        }
        .sheet(isPresented: $showPasteRecorder) {
            PasteHotkeyRecorderView()
                .padding()
        }
        .alert("Clear Clipboard History?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clipboardManager.clearHistory()
            }
        } message: {
            Text("This will permanently delete all clipboard history items and free up \(formatBytes(clipboardManager.totalStorageUsed)).")
        }
        .onAppear {
            updatePermissions()
        }
        .onReceive(timer) { _ in
            updatePermissions()
        }
    }
    
    // MARK: - Helpers
    
    private func updatePermissions() {
        screenRecordingGranted = screenshotManager.isScreenRecordingGranted()
        accessibilityGranted = screenshotManager.isAccessibilityGranted()
    }
    
    private var usageProgress: Double {
        guard !storageLimit.isUnlimited else { return 0.1 }
        return min(Double(clipboardManager.totalStorageUsed) / Double(storageLimit.bytes), 1.0)
    }

    private var usageColor: Color {
        guard !storageLimit.isUnlimited else { return .blue }
        let percentage = Double(clipboardManager.totalStorageUsed) / Double(storageLimit.bytes)
        if percentage >= 0.9 { return .red }
        if percentage >= 0.7 { return .orange }
        return .blue
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
