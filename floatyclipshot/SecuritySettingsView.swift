//
//  SecuritySettingsView.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Security and privacy settings UI for FloatyClipshot
//

import SwiftUI

struct SecuritySettingsView: View {
    @State private var encryptionEnabled = SettingsManager.shared.encryptionEnabled
    @State private var privateModeEnabled = SettingsManager.shared.privateModeEnabled
    @State private var autoDetectSensitive = SettingsManager.shared.autoDetectSensitive
    @State private var sensitivePurgeMinutes = SettingsManager.shared.sensitivePurgeMinutes

    @State private var showingEncryptionAlert = false
    @State private var showingDeleteKeyAlert = false
    @State private var isEncrypting = false

    var body: some View {
        Form {
            // MARK: - Private Mode Section
            Section {
                Toggle(isOn: $privateModeEnabled) {
                    HStack {
                        Image(systemName: privateModeEnabled ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(privateModeEnabled ? .orange : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private Mode")
                                .font(.headline)
                            Text(privateModeEnabled ? "Clipboard monitoring paused" : "Monitoring active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: privateModeEnabled) { _, newValue in
                    SettingsManager.shared.privateModeEnabled = newValue
                    // Also update ClipboardManager directly
                    ClipboardManager.shared.isPaused = newValue
                }
            } header: {
                Label("Privacy", systemImage: "hand.raised.fill")
            } footer: {
                Text("When enabled, new clipboard items won't be recorded until you disable it.")
            }

            // MARK: - Encryption Section
            Section {
                Toggle(isOn: $encryptionEnabled) {
                    HStack {
                        Image(systemName: encryptionEnabled ? "lock.fill" : "lock.open")
                            .foregroundStyle(encryptionEnabled ? .green : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Encrypt History")
                                .font(.headline)
                            Text(encryptionEnabled ? "Data encrypted at rest" : "Data stored unencrypted")
                                .font(.caption)
                                .foregroundStyle(encryptionEnabled ? .green : .orange)
                        }
                    }
                }
                .onChange(of: encryptionEnabled) { oldValue, newValue in
                    if newValue && !oldValue {
                        // Turning ON encryption
                        showingEncryptionAlert = true
                    } else if !newValue && oldValue {
                        // Turning OFF encryption - just save setting
                        SettingsManager.shared.encryptionEnabled = newValue
                    }
                }

                if encryptionEnabled {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("Encryption Key")
                        Spacer()
                        if EncryptionManager.shared.hasExistingKey {
                            Label("Stored in Keychain", systemImage: "checkmark.shield.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Not configured", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Label("Encryption", systemImage: "lock.shield.fill")
            } footer: {
                if encryptionEnabled {
                    Text("Your clipboard history is encrypted using AES-256. The encryption key is stored securely in your Mac's Keychain.")
                } else {
                    Text("Warning: Clipboard history is stored unencrypted. Anyone with access to your Mac can read this data.")
                        .foregroundStyle(.orange)
                }
            }

            // MARK: - Sensitive Data Section
            Section {
                Toggle(isOn: $autoDetectSensitive) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundStyle(autoDetectSensitive ? .blue : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Detect Sensitive Data")
                                .font(.headline)
                            Text("Passwords, API keys, tokens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: autoDetectSensitive) { _, newValue in
                    SettingsManager.shared.autoDetectSensitive = newValue
                }

                if autoDetectSensitive {
                    Picker(selection: $sensitivePurgeMinutes) {
                        ForEach(SettingsManager.SensitivePurgeInterval.allCases, id: \.rawValue) { interval in
                            Text(interval.displayName).tag(interval.rawValue)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "clock.badge.xmark")
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text("Auto-delete sensitive items")
                        }
                    }
                    .onChange(of: sensitivePurgeMinutes) { _, newValue in
                        SettingsManager.shared.sensitivePurgeMinutes = newValue
                    }
                }
            } header: {
                Label("Sensitive Data", systemImage: "eye.trianglebadge.exclamationmark")
            } footer: {
                if autoDetectSensitive {
                    Text("Detected patterns: API keys, passwords, private keys, connection strings, tokens, credit cards.")
                } else {
                    Text("All clipboard items will be treated equally regardless of content.")
                }
            }

            // MARK: - Danger Zone
            Section {
                Button(role: .destructive) {
                    showingDeleteKeyAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .frame(width: 24)
                        Text("Delete Encryption Key")
                    }
                }
                .disabled(!EncryptionManager.shared.hasExistingKey)
            } header: {
                Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
            } footer: {
                Text("Deleting the encryption key will make all previously encrypted data permanently unreadable.")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .alert("Enable Encryption?", isPresented: $showingEncryptionAlert) {
            Button("Enable") {
                enableEncryption()
            }
            Button("Cancel", role: .cancel) {
                encryptionEnabled = false
            }
        } message: {
            Text("This will encrypt your clipboard history. A new encryption key will be generated and stored in your Mac's Keychain.\n\nExisting unencrypted data will remain readable.")
        }
        .alert("Delete Encryption Key?", isPresented: $showingDeleteKeyAlert) {
            Button("Delete", role: .destructive) {
                deleteEncryptionKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All encrypted clipboard history will become permanently unreadable.")
        }
        .overlay {
            if isEncrypting {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Encrypting...")
                            .font(.headline)
                    }
                    .padding(32)
                    .background {
                        RoundedRectangle(cornerRadius: GlassDesign.Radius.large)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Actions

    private func enableEncryption() {
        isEncrypting = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Verify encryption is available
            let isAvailable = EncryptionManager.shared.isEncryptionAvailable

            DispatchQueue.main.async {
                isEncrypting = false

                if isAvailable {
                    SettingsManager.shared.encryptionEnabled = true
                    encryptionEnabled = true
                    print("Encryption enabled successfully")
                } else {
                    encryptionEnabled = false
                    // Show error (could add another alert here)
                    print("Failed to enable encryption")
                }
            }
        }
    }

    private func deleteEncryptionKey() {
        do {
            try EncryptionManager.shared.deleteKey()
            encryptionEnabled = false
            SettingsManager.shared.encryptionEnabled = false
            print("Encryption key deleted")
        } catch {
            print("Failed to delete encryption key: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    SecuritySettingsView()
        .frame(width: 400, height: 600)
}

// MARK: - Private Mode Quick Toggle (for menu bar / floating button)

struct PrivateModeToggleButton: View {
    @State private var isPrivate = SettingsManager.shared.privateModeEnabled

    var compact: Bool = false

    var body: some View {
        Button {
            isPrivate.toggle()
            SettingsManager.shared.privateModeEnabled = isPrivate
            ClipboardManager.shared.isPaused = isPrivate
        } label: {
            if compact {
                Image(systemName: isPrivate ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(isPrivate ? .orange : .secondary)
            } else {
                Label(
                    isPrivate ? "Private Mode ON" : "Private Mode OFF",
                    systemImage: isPrivate ? "eye.slash.fill" : "eye.fill"
                )
                .foregroundStyle(isPrivate ? .orange : .primary)
            }
        }
        .help(isPrivate ? "Private Mode: Clipboard monitoring paused" : "Click to pause clipboard monitoring")
        .onReceive(NotificationCenter.default.publisher(for: .privateModeChanged)) { notification in
            if let enabled = notification.userInfo?["enabled"] as? Bool {
                isPrivate = enabled
            }
        }
    }
}

// MARK: - Encryption Status Badge

struct EncryptionStatusBadge: View {
    var showLabel: Bool = true

    var body: some View {
        let isEncrypted = SettingsManager.shared.encryptionEnabled

        HStack(spacing: 4) {
            Image(systemName: isEncrypted ? "lock.fill" : "lock.open")
                .font(.caption)
            if showLabel {
                Text(isEncrypted ? "Encrypted" : "Unencrypted")
                    .font(.caption)
            }
        }
        .foregroundStyle(isEncrypted ? .green : .orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isEncrypted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
        )
    }
}
