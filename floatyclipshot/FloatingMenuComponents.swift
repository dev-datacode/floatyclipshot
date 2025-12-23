//
//  FloatingMenuComponents.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Reusable UI components for the floating menu system
//

import SwiftUI

// MARK: - Menu Card

struct MenuCard<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: GlassDesign.Spacing.md - 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 28)
                .glassSymbolTransition()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            trailing()
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.Radius.medium)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
        .glassHover(scale: 1.01, brightness: 0.02)
    }
}

// MARK: - Menu Button

struct MenuButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 24)
                    .glassSymbolTransition()

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: GlassDesign.Radius.small)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .opacity(0.6)
            }
        }
        .buttonStyle(.plain)
        .glassHover(scale: 1.01, brightness: 0.03)
        .glassPress(scale: 0.98)
    }
}

// MARK: - Window Row

struct WindowRow: View {
    let window: WindowInfo
    let isSelected: Bool
    let tag: WindowTag?
    let pairing: WindowPairing?
    let isHovered: Bool
    let previousFrontmostApp: String
    let onSelect: () -> Void
    let onTag: () -> Void
    let onPair: () -> Void
    let onUnpair: () -> Void

    // Cached source app status
    private let isSourceApp: Bool

    // Group pairing info
    private var groupId: String? {
        GroupPairingManager.shared.getGroupId(for: window)
    }

    private var isPrimary: Bool {
        GroupPairingManager.shared.isPrimary(for: window)
    }

    init(window: WindowInfo, isSelected: Bool, tag: WindowTag?, pairing: WindowPairing?, isHovered: Bool, previousFrontmostApp: String, onSelect: @escaping () -> Void, onTag: @escaping () -> Void, onPair: @escaping () -> Void, onUnpair: @escaping () -> Void) {
        self.window = window
        self.isSelected = isSelected
        self.tag = tag
        self.pairing = pairing
        self.isHovered = isHovered
        self.previousFrontmostApp = previousFrontmostApp
        self.onSelect = onSelect
        self.onTag = onTag
        self.onPair = onPair
        self.onUnpair = onUnpair

        let category = AppRegistry.category(forAppName: window.ownerName)
        self.isSourceApp = (category == .terminal || category == .ide || category == .aiChat ||
                           category == .messaging || category == .browser || category == .documentation ||
                           category == .ticketing || category == .email || category == .textEditor)
    }

    // Check if we came from a source app (can pair)
    private var canPair: Bool {
        // Any window can be a capture target, so allow pairing if we came from any app
        // Pairing creates source→capture relationship
        !window.ownerName.isEmpty && !previousFrontmostApp.isEmpty
    }

    // Truncate window title for display
    private var windowTitle: String {
        let title = window.name.isEmpty ? "" : window.name
        if title.count > 35 {
            return String(title.prefix(35)) + "..."
        }
        return title
    }

    var body: some View {
        HStack(spacing: GlassDesign.Spacing.sm) {
            // Group badge or tag color
            if let group = groupId {
                // Show group badge
                Text(group)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isPrimary ? Color.green : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Circle()
                    .fill(tag?.tagColor.color ?? .clear)
                    .stroke(tag == nil ? Color.secondary.opacity(0.3) : .clear, lineWidth: 1)
                    .frame(width: 10, height: 10)
                    .shadow(color: (tag?.tagColor.color ?? .clear).opacity(0.5), radius: 3)
            }

            // Window info - show app name AND window title
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: GlassDesign.Spacing.xs) {
                    // Main line: tag name or app name
                    Text(tag?.projectName ?? window.ownerName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Show primary indicator
                    if isPrimary {
                        Text("Primary")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(.green)
                    }

                    // Show link indicator if paired (legacy)
                    if pairing != nil && groupId == nil {
                        Image(systemName: "link")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                            .glassSymbolTransition()
                    }
                }

                // Subtitle: window title (page title, document name, etc.)
                if !windowTitle.isEmpty {
                    Text(windowTitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if tag != nil {
                    // Show app name if we have a tag but no window title
                    Text(window.ownerName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Show pairing info if this window is paired (legacy)
                if let pairing = pairing, groupId == nil {
                    Text("← \(pairing.sourceDisplayName)")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions
            if isHovered {
                HStack(spacing: GlassDesign.Spacing.xs) {
                    // Pair/Unpair button (show for potential capture targets)
                    if !isSourceApp {
                        if pairing != nil {
                            // Unpair button
                            GlassIconButton(icon: "link.badge.plus", color: .orange, size: 10, action: onUnpair)
                                .help("Remove terminal pairing")
                        } else if canPair {
                            // Pair button (only if we came from a terminal)
                            GlassIconButton(icon: "link", color: .secondary, size: 10, action: onPair)
                                .help("Pair with \(previousFrontmostApp)")
                        }
                    }

                    // Tag button
                    GlassIconButton(
                        icon: tag == nil ? "tag" : "tag.fill",
                        color: tag?.tagColor.color ?? .secondary,
                        size: 10,
                        action: onTag
                    )

                    // Select button
                    GlassIconButton(icon: "scope", color: .blue, size: 10, action: onSelect)
                }
                .transition(.scale.combined(with: .opacity))
            } else if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                    .glassSymbolTransition()
            } else if groupId != nil {
                // Show group indicator when not hovered
                Image(systemName: isPrimary ? "arrow.right.circle.fill" : "circle")
                    .font(.system(size: 9))
                    .foregroundStyle(isPrimary ? .green : .orange)
                    .glassSymbolTransition()
            } else if pairing != nil {
                // Show link indicator when not hovered (legacy)
                Image(systemName: "link")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .glassSymbolTransition()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.Radius.small)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .opacity(isSelected ? 1 : (isHovered ? 0.8 : 0.3))
        }
        .animation(GlassDesign.Animation.quick, value: isHovered)
        .animation(GlassDesign.Animation.quick, value: isSelected)
    }
}

// MARK: - Clipboard Item Row

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let action: () -> Void

    private var icon: String {
        switch item.type {
        case .image: return "photo.fill"
        case .text: return "doc.text.fill"
        case .unknown: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .image: return .purple
        case .text: return .blue
        case .unknown: return .gray
        }
    }

    private var shortName: String {
        switch item.type {
        case .image:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Screenshot \(formatter.string(from: item.timestamp))"
        case .text(let preview):
            return String(preview.prefix(25)) + (preview.count > 25 ? "..." : "")
        case .unknown:
            return "Item"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                    .glassSymbolTransition()

                VStack(alignment: .leading, spacing: 2) {
                    Text(shortName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let context = item.windowContext {
                        Text(context)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                        .glassPulse(color: .yellow, duration: 2.0)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: GlassDesign.Radius.small)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                    .opacity(0.4)
            }
        }
        .buttonStyle(.plain)
        .glassHover(scale: 1.02, brightness: 0.03)
        .glassPress(scale: 0.97)
    }
}

// MARK: - Quick Pair Row

struct QuickPairRow: View {
    let target: WindowInfo
    let existingPairing: WindowPairing?
    let onPair: () -> Void
    let onUnpair: () -> Void
    let onCapture: () -> Void

    private var icon: String {
        switch target.ownerName {
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
        switch target.ownerName {
        case "Simulator": return .blue
        case "Safari": return .blue
        case "Google Chrome": return .green
        case "Firefox": return .orange
        case "Arc": return .purple
        case "Preview": return .pink
        default: return .gray
        }
    }

    private var displayTitle: String {
        if target.name.isEmpty {
            return target.ownerName
        }
        let name = target.name
        if name.count > 30 {
            return String(name.prefix(30)) + "..."
        }
        return name
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24)
                .glassSymbolTransition()

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !target.name.isEmpty {
                    Text(target.ownerName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                if let pairing = existingPairing {
                    Text("Paired to: \(pairing.sourceDisplayName)")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: GlassDesign.Spacing.sm) {
                // Pair/Unpair button
                if existingPairing != nil {
                    GlassIconButton(icon: "link.badge.plus", color: .orange, size: 12, action: onUnpair)
                        .help("Remove pairing")
                } else {
                    Button(action: onPair) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                            Text("Pair")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, GlassDesign.Spacing.sm)
                        .padding(.vertical, GlassDesign.Spacing.xs)
                        .background {
                            Capsule()
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .glassPress(scale: 0.95)
                    .help("Pair terminal to this window")
                }

                // Capture button
                GlassIconButton(icon: "camera.fill", color: .blue, size: 12, action: onCapture)
                    .help("Capture now")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.Radius.small)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
        .glassHover(scale: 1.01, brightness: 0.02)
    }
}
