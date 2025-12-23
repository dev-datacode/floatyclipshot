//
//  StorageSettingsView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import SwiftUI

struct StorageSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var clipboardManager = ClipboardManager.shared

    @State private var selectedLimit: StorageLimit
    @State private var showClearConfirmation = false

    init() {
        _selectedLimit = State(initialValue: SettingsManager.shared.storageLimit)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Clipboard Storage Settings")
                .font(.title2)
                .bold()

            // Current usage indicator
            storageUsageSection

            Divider()

            // Storage limit selector
            storageLimitSection

            Divider()

            // Actions
            actionButtonsSection
        }
        .padding(24)
        .frame(width: 450)
        .alert("Clear Clipboard History?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clipboardManager.clearHistory()
            }
        } message: {
            Text("This will permanently delete all clipboard history items and free up \(formatBytes(clipboardManager.totalStorageUsed)).")
        }
    }

    // MARK: - Subviews

    private var storageUsageSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Current Usage")
                    .font(.headline)
                Spacer()
                Text(formatBytes(clipboardManager.totalStorageUsed))
                    .font(.title3)
                    .bold()
                    .foregroundColor(usageColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(usageColor)
                        .frame(width: geometry.size.width * usageProgress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(clipboardManager.clipboardHistory.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if !selectedLimit.isUnlimited {
                    Text("Limit: \(selectedLimit.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var storageLimitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Limit")
                .font(.headline)

            Text("When the limit is reached, the oldest items will be automatically removed to free up 30% of space.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("", selection: $selectedLimit) {
                ForEach(StorageLimit.allCases, id: \.self) { limit in
                    Text(limit.displayName).tag(limit)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button("Clear History") {
                showClearConfirmation = true
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)

            Button("Save") {
                saveSettings()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private var usageProgress: Double {
        guard !selectedLimit.isUnlimited else { return 0.1 }
        return min(Double(clipboardManager.totalStorageUsed) / Double(selectedLimit.bytes), 1.0)
    }

    private var usageColor: Color {
        guard !selectedLimit.isUnlimited else { return .blue }

        let percentage = Double(clipboardManager.totalStorageUsed) / Double(selectedLimit.bytes)

        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .blue
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func saveSettings() {
        SettingsManager.shared.storageLimit = selectedLimit

        // Trigger cleanup if new limit is lower than current usage
        if !selectedLimit.isUnlimited && clipboardManager.totalStorageUsed > selectedLimit.bytes {
            // Will be handled automatically by next clipboard update
            // Or we can trigger it immediately:
            let targetSize = SettingsManager.shared.calculateTargetSize(for: selectedLimit)
            clipboardManager.performManualCleanup(targetSize: targetSize)
        }

        dismiss()
    }
}

#Preview {
    StorageSettingsView()
        .frame(width: 450, height: 400)
}
