//
//  PermissionsView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/23/25.
//
//  UI for requesting and managing system permissions
//

import SwiftUI
import Combine

struct PermissionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isAccessibilityGranted = false
    @State private var isScreenRecordingGranted = false

    // Timer to auto-refresh status when user switches back to app
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Permissions Required")
                    .font(.title2)
                    .bold()

                Text("FloatyClipshot needs these permissions to capture screens and paste paths.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }

            Divider()

            // Permissions List
            VStack(spacing: 20) {
                // Screen Recording
                HStack {
                    Image(systemName: "rectangle.dashed.badge.record")
                        .font(.system(size: 24))
                        .foregroundColor(isScreenRecordingGranted ? .green : .orange)
                        .frame(width: 32)

                    VStack(alignment: .leading) {
                        Text("Screen Recording")
                            .font(.headline)
                        Text("Required to capture screenshots.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isScreenRecordingGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Open Settings") {
                            ScreenshotManager.shared.openSystemSettings(for: .screenRecording)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                // Accessibility
                HStack {
                    Image(systemName: "keyboard")
                        .font(.system(size: 24))
                        .foregroundColor(isAccessibilityGranted ? .green : .orange)
                        .frame(width: 32)

                    VStack(alignment: .leading) {
                        Text("Accessibility")
                            .font(.headline)
                        Text("Required to paste paths automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isAccessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Open Settings") {
                            ScreenshotManager.shared.openSystemSettings(for: .accessibility)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            // Footer
            HStack {
                if isAccessibilityGranted && isScreenRecordingGranted {
                    Text("All Set!")
                        .foregroundColor(.green)
                        .bold()
                } else {
                    Text("Please grant permissions to continue.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 450)
        .onAppear(perform: checkPermissions)
        .onReceive(timer) { _ in
            checkPermissions()
        }
    }

    private func checkPermissions() {
        isAccessibilityGranted = ScreenshotManager.shared.isAccessibilityGranted()
        isScreenRecordingGranted = ScreenshotManager.shared.isScreenRecordingGranted()
    }
}

#Preview {
    PermissionsView()
}
