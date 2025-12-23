//
//  CaptureDetailView.swift
//  floatyclipshot
//

import SwiftUI
import AppKit

struct CaptureDetailView: View {
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var pairingManager = PairingManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GlassDesign.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
                    Text("Quick Capture")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Capture screenshots and automatically paste file paths to your terminal.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .glassAppearAnimation(delay: 0)

                GlassDivider()

                // Current Status
                GlassCard(tint: .blue.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.md) {
                        Label("Current Status", systemImage: "info.circle.fill")
                            .font(.headline)

                        HStack(spacing: GlassDesign.Spacing.lg - 4) {
                            StatusCard(
                                title: "Target",
                                value: windowManager.selectedWindow?.displayName ?? "Full Screen",
                                icon: "scope",
                                color: .blue
                            )

                            StatusCard(
                                title: "Pairings",
                                value: "\(pairingManager.pairings.count) active",
                                icon: "link.circle",
                                color: .orange
                            )

                            StatusCard(
                                title: "Auto-Pair",
                                value: statusText,
                                icon: statusIcon,
                                color: statusColor
                            )
                        }
                    }
                }
                .glassAppearAnimation(delay: 0.05)

                // Quick Actions
                GlassCard(tint: .green.opacity(0.3)) {
                    VStack(alignment: .leading, spacing: GlassDesign.Spacing.md) {
                        Label("Quick Actions", systemImage: "bolt.fill")
                            .font(.headline)

                        HStack(spacing: GlassDesign.Spacing.md - 4) {
                            ActionButton(
                                title: "Capture Screen",
                                subtitle: hotkeyManager.hotkeyDisplayString,
                                icon: "camera.fill",
                                color: .blue
                            ) {
                                screenshotManager.captureFullScreen()
                            }

                            ActionButton(
                                title: "Capture & Paste",
                                subtitle: hotkeyManager.pasteHotkeyDisplayString,
                                icon: "doc.on.clipboard.fill",
                                color: .green
                            ) {
                                screenshotManager.captureAndPaste()
                            }

                            ActionButton(
                                title: "Select Region",
                                subtitle: "Interactive",
                                icon: "crop",
                                color: .purple
                            ) {
                                screenshotManager.captureRegion()
                            }
                        }
                    }
                }
                .glassAppearAnimation(delay: 0.1)

                // On-Screen Targets
                let targets = screenshotManager.getOnScreenTargets()
                if !targets.isEmpty {
                    GlassCard(tint: .purple.opacity(0.3)) {
                        VStack(alignment: .leading, spacing: GlassDesign.Spacing.md - 4) {
                            Label("Available Targets on This Space", systemImage: "rectangle.stack")
                                .font(.headline)

                            ForEach(targets) { target in
                                TargetRow(target: target)
                            }
                        }
                    }
                    .glassAppearAnimation(delay: 0.15)
                }

                Spacer()
            }
            .padding(GlassDesign.Spacing.lg)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var statusText: String {
        switch screenshotManager.autoPairingStatus {
        case .none: return "No targets"
        case .ready: return "Ready"
        case .multiple: return "Multiple"
        case .paired: return "Paired"
        }
    }

    private var statusIcon: String {
        switch screenshotManager.autoPairingStatus {
        case .none: return "xmark.circle"
        case .ready: return "checkmark.circle"
        case .multiple: return "list.bullet.circle"
        case .paired: return "link.circle"
        }
    }

    private var statusColor: Color {
        switch screenshotManager.autoPairingStatus {
        case .none: return .gray
        case .ready: return .blue
        case .multiple: return .purple
        case .paired: return .orange
        }
    }
}
