//
//  MainPanelComponents.swift
//  floatyclipshot
//

import SwiftUI
import AppKit

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: GlassDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .glassSymbolTransition()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GlassDesign.Spacing.md - 4)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.Radius.medium)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
        .glassHover(scale: 1.02, brightness: 0.03)
    }
}

struct ActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: GlassDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .glassSymbolTransition()

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GlassDesign.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: GlassDesign.Radius.medium)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
            }
            .overlay {
                RoundedRectangle(cornerRadius: GlassDesign.Radius.medium)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .glassHover(scale: 1.02, brightness: 0.03)
        .glassPress(scale: 0.96)
    }
}

struct TargetRow: View {
    let target: WindowInfo
    @ObservedObject private var pairingManager = PairingManager.shared
    @ObservedObject private var screenshotManager = ScreenshotManager.shared

    private var icon: String {
        switch target.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Firefox": return "flame"
        case "Arc": return "circle.hexagongrid"
        default: return "macwindow"
        }
    }

    private var iconColor: Color {
        switch target.ownerName {
        case "Simulator": return .blue
        case "Safari": return .blue
        case "Google Chrome": return .green
        case "Firefox": return .orange
        case "Arc": return .purple
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(target.name.isEmpty ? target.ownerName : target.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if !target.name.isEmpty {
                    Text(target.ownerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if pairingManager.hasPairing(forCaptureTarget: target) {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.orange)
            }

            Button("Capture") {
                screenshotManager.captureWithTarget(target, andCreatePairing: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 8)
    }
}

struct WindowListRow: View {
    let window: WindowInfo
    let isSelected: Bool
    let onSelect: () -> Void

    private var icon: String {
        switch window.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Firefox": return "flame"
        case "Arc": return "circle.hexagongrid"
        case "Finder": return "folder"
        case "Preview": return "photo"
        default: return "macwindow"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.name.isEmpty ? window.ownerName : window.name)
                    .font(.body)
                    .lineLimit(1)

                if !window.name.isEmpty {
                    Text(window.ownerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }

            Button(isSelected ? "Selected" : "Select") {
                onSelect()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isSelected)
        }
        .padding(.vertical, 4)
    }
}

struct UniversalPairingListRow: View {
    let pairing: WindowPairing
    let onDelete: () -> Void

    /// Get icon for source app category
    private var sourceIcon: String {
        let category = AppRegistry.category(forAppName: pairing.sourceOwnerName)
        switch category {
        case .terminal: return "terminal"
        case .ide: return "chevron.left.forwardslash.chevron.right"
        case .aiChat: return "bubble.left.and.bubble.right"
        case .messaging: return "message"
        case .browser: return "globe"
        case .documentation: return "doc.text"
        case .ticketing: return "ticket"
        case .design: return "paintbrush"
        case .email: return "envelope"
        case .textEditor: return "text.cursor"
        case .generic: return "app"
        }
    }

    /// Get icon for capture target
    private var captureIcon: String {
        switch pairing.captureOwnerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Firefox": return "flame"
        case "Arc": return "circle.hexagongrid"
        case "Preview": return "photo"
        default: return "macwindow"
        }
    }

    /// Get paste mode icon
    private var pasteModeIcon: String {
        switch pairing.pasteMode {
        case .filePath: return "doc.text"
        case .image: return "photo"
        case .auto: return "sparkles"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: sourceIcon)
                        .foregroundStyle(.blue)
                    Text(pairing.sourceDisplayName)
                        .fontWeight(.medium)
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: captureIcon)
                        .foregroundStyle(.green)
                    Text(pairing.captureDisplayName)

                    // Paste mode badge
                    HStack(spacing: 2) {
                        Image(systemName: pasteModeIcon)
                            .font(.system(size: 8))
                        Text(pairing.pasteMode.displayName)
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct ClipboardCard: View {
    let item: ClipboardItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: GlassDesign.Spacing.sm) {
                // Thumbnail
                Group {
                    if case .image = item.type,
                       let fileURL = item.fileURL,
                       let nsImage = NSImage(contentsOf: fileURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)
                .clipped()
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let context = item.windowContext {
                        Text(context)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GlassDesign.Spacing.sm)
                .padding(.bottom, GlassDesign.Spacing.sm)
            }
            .background {
                RoundedRectangle(cornerRadius: GlassDesign.Radius.medium)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
            }
            .clipShape(RoundedRectangle(cornerRadius: GlassDesign.Radius.medium))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .glassHover(scale: 1.03, brightness: 0.02)
        .glassPress(scale: 0.96)
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let openSettings: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                Button("Enable") {
                    openSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SourceWindowRow: View {
    let window: WindowInfo
    let isSelected: Bool

    private var categoryIcon: String {
        let category = AppRegistry.category(forAppName: window.ownerName)
        switch category {
        case .terminal: return "terminal"
        case .ide: return "chevron.left.forwardslash.chevron.right"
        case .aiChat: return "bubble.left.and.bubble.right"
        case .messaging: return "message"
        case .browser: return "globe"
        case .documentation: return "doc.text"
        case .ticketing: return "ticket"
        case .design: return "paintbrush"
        case .email: return "envelope"
        case .textEditor: return "text.cursor"
        case .generic: return "app"
        }
    }

    private var categoryColor: Color {
        let category = AppRegistry.category(forAppName: window.ownerName)
        switch category {
        case .terminal, .ide, .textEditor: return .blue
        case .aiChat: return .purple
        case .messaging: return .green
        case .browser: return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: categoryIcon)
                .foregroundStyle(categoryColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.ownerName)
                    .font(.system(size: 12, weight: .medium))
                if !window.name.isEmpty {
                    Text(window.name.prefix(40) + (window.name.count > 40 ? "..." : ""))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct TargetWindowRow: View {
    let window: WindowInfo
    let isSelected: Bool

    private var icon: String {
        switch window.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Firefox": return "flame"
        case "Arc": return "circle.hexagongrid"
        case "Preview": return "photo"
        default: return "macwindow"
        }
    }

    private var iconColor: Color {
        switch window.ownerName {
        case "Simulator": return .blue
        case "Safari": return .blue
        case "Google Chrome": return .green
        case "Firefox": return .orange
        case "Arc": return .purple
        case "Preview": return .pink
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.ownerName)
                    .font(.system(size: 12, weight: .medium))
                if !window.name.isEmpty {
                    Text(window.name.prefix(40) + (window.name.count > 40 ? "..." : ""))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
