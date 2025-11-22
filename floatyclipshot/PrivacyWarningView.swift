//
//  PrivacyWarningView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import SwiftUI

struct PrivacyWarningView: View {
    @Environment(\.dismiss) var dismiss
    @State private var acknowledgedRisks = false

    var body: some View {
        VStack(spacing: 20) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            // Title
            Text("Privacy & Security Notice")
                .font(.title)
                .bold()

            // Warning content
            VStack(alignment: .leading, spacing: 12) {
                Text("⚠️ **Important Information**")
                    .font(.headline)

                Text("FloatyClipshot monitors and stores your clipboard history, including:")
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    privacyRiskItem("🔑 Passwords and API keys")
                    privacyRiskItem("💳 Credit card numbers")
                    privacyRiskItem("📱 2FA codes")
                    privacyRiskItem("💬 Private messages")
                    privacyRiskItem("📄 All text and images you copy")
                }
                .padding(.leading, 16)

                Divider()

                Text("**Data Storage:**")
                    .font(.headline)

                Text("All clipboard data is stored unencrypted in:\n~/Library/Application Support/FloatyClipshot/")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)

                Divider()

                Text("**Privacy Recommendations:**")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("• Pause monitoring when copying sensitive data")
                    Text("• Clear history regularly")
                    Text("• Don't use on shared computers")
                    Text("• Encrypt your Mac's disk (FileVault)")
                }
                .font(.caption)
                .padding(.leading, 16)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )

            // Acknowledgment
            Toggle(isOn: $acknowledgedRisks) {
                Text("I understand the privacy implications")
                    .font(.body)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button("Quit App") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Continue") {
                    SettingsManager.shared.setPrivacyWarningShown()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(!acknowledgedRisks)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 550)
    }

    private func privacyRiskItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.body)
    }
}

#Preview {
    PrivacyWarningView()
}
