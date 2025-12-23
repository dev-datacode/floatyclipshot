//
//  GlassComponents.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Shared Liquid Glass UI components following Apple's iOS 26+ design system
//

import SwiftUI

// MARK: - Design Tokens

/// Liquid Glass design tokens based on Apple HIG
struct GlassDesign {
    // MARK: - Transparency Scale
    struct Opacity {
        static let vital: Double = 1.0      // Main text, primary CTAs, logos
        static let supporting: Double = 0.7  // Secondary buttons, nav tabs
        static let decorative: Double = 0.4  // Dividers, outlines, icons
        static let subtle: Double = 0.2      // Tints, overlays, atmospheric
    }

    // MARK: - Spacing Scale
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radii
    struct Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let capsule: CGFloat = 100  // For pill shapes
    }

    // MARK: - Touch Targets
    static let minTouchTarget: CGFloat = 44

    // MARK: - Animation
    struct Animation {
        static let quick: SwiftUI.Animation = .easeInOut(duration: 0.15)
        static let standard: SwiftUI.Animation = .easeInOut(duration: 0.25)
        static let smooth: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.8)
        static let bouncy: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.7)
    }
}

// MARK: - Glass Card

/// A card container with Liquid Glass styling
struct GlassCard<Content: View>: View {
    let content: Content
    var tint: Color?
    var cornerRadius: CGFloat
    var padding: CGFloat

    init(
        tint: Color? = nil,
        cornerRadius: CGFloat = GlassDesign.Radius.medium,
        padding: CGFloat = GlassDesign.Spacing.md,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
            }
    }
}

// MARK: - Glass Button

/// An interactive button with Liquid Glass styling
struct GlassButton: View {
    let title: String
    let icon: String?
    let color: Color
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary    // Filled glass with tint
        case secondary  // Subtle glass
        case outline    // Border only
        case icon       // Icon-only circular
    }

    @State private var isHovered = false
    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        color: Color = .blue,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(GlassDesign.Animation.quick) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(GlassDesign.Animation.quick, value: isPressed)
    }

    @ViewBuilder
    private var buttonContent: some View {
        switch style {
        case .primary:
            primaryButton
        case .secondary:
            secondaryButton
        case .outline:
            outlineButton
        case .icon:
            iconButton
        }
    }

    private var primaryButton: some View {
        HStack(spacing: GlassDesign.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, GlassDesign.Spacing.md)
        .padding(.vertical, GlassDesign.Spacing.sm + 2)
        .background {
            Capsule()
                .fill(color)
        }
        .brightness(isHovered ? 0.1 : 0)
    }

    private var secondaryButton: some View {
        HStack(spacing: GlassDesign.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, GlassDesign.Spacing.md)
        .padding(.vertical, GlassDesign.Spacing.sm + 2)
        .background {
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
    }

    private var outlineButton: some View {
        HStack(spacing: GlassDesign.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, GlassDesign.Spacing.md)
        .padding(.vertical, GlassDesign.Spacing.sm + 2)
        .background {
            Capsule()
                .stroke(color.opacity(isHovered ? 0.8 : 0.5), lineWidth: 1.5)
                .background(Capsule().fill(isHovered ? color.opacity(0.1) : .clear))
        }
    }

    private var iconButton: some View {
        Image(systemName: icon ?? "circle")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(isHovered ? color : .secondary)
            .frame(width: GlassDesign.minTouchTarget, height: GlassDesign.minTouchTarget)
            .background {
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
            }
    }
}

// MARK: - Glass Icon Button

/// A simple icon button with glass effect
struct GlassIconButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    init(
        icon: String,
        color: Color = .primary,
        size: CGFloat = 20,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isHovered ? color : .secondary)
                .frame(width: max(size + 24, GlassDesign.minTouchTarget),
                       height: max(size + 24, GlassDesign.minTouchTarget))
                .background {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                        .opacity(isHovered ? 1 : 0.6)
                }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(GlassDesign.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Glass Toggle

/// A toggle switch with Liquid Glass styling
struct GlassToggle: View {
    @Binding var isOn: Bool
    let label: String
    let icon: String?
    let tint: Color

    init(
        _ label: String,
        icon: String? = nil,
        isOn: Binding<Bool>,
        tint: Color = .blue
    ) {
        self.label = label
        self.icon = icon
        self._isOn = isOn
        self.tint = tint
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: GlassDesign.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isOn ? tint : .secondary)
                        .frame(width: 24)
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .toggleStyle(.switch)
        .tint(tint)
    }
}

// MARK: - Glass Segmented Control

/// A segmented picker with Liquid Glass styling
struct GlassSegmentedPicker<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    let content: Content

    init(
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        Picker("", selection: $selection) {
            content
        }
        .pickerStyle(.segmented)
        .background {
            RoundedRectangle(cornerRadius: GlassDesign.Radius.small)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
    }
}

// MARK: - Glass Divider

/// A subtle divider for glass surfaces
struct GlassDivider: View {
    let opacity: Double

    init(opacity: Double = GlassDesign.Opacity.decorative) {
        self.opacity = opacity
    }

    var body: some View {
        Divider()
            .opacity(opacity)
    }
}

// MARK: - Glass Badge

/// A notification badge with glass styling
struct GlassBadge: View {
    let count: Int
    let color: Color
    let maxDisplay: Int

    init(count: Int, color: Color = .red, maxDisplay: Int = 99) {
        self.count = count
        self.color = color
        self.maxDisplay = maxDisplay
    }

    var body: some View {
        if count > 0 {
            Text(count > maxDisplay ? "\(maxDisplay)+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    Capsule()
                        .fill(color)
                }
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Glass Tooltip

/// A tooltip with Liquid Glass styling
struct GlassTooltip: View {
    let text: String
    let icon: String?

    init(_ text: String, icon: String? = nil) {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: GlassDesign.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, GlassDesign.Spacing.sm + 4)
        .padding(.vertical, GlassDesign.Spacing.sm)
        .background {
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}

// MARK: - Glass Progress

/// A progress indicator with glass styling
struct GlassProgress: View {
    let value: Double  // 0.0 to 1.0
    let color: Color
    let height: CGFloat

    init(value: Double, color: Color = .blue, height: CGFloat = 6) {
        self.value = min(max(value, 0), 1)
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))

                // Fill
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Preview

#Preview("Glass Components") {
    VStack(spacing: 24) {
        // Cards
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Glass Card")
                    .font(.headline)
                Text("A card with Liquid Glass material")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        GlassCard(tint: .blue) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Tinted glass card")
            }
        }

        // Buttons
        HStack(spacing: 12) {
            GlassButton("Primary", icon: "star.fill", color: .blue, style: .primary) {}
            GlassButton("Secondary", style: .secondary) {}
            GlassButton("Outline", color: .orange, style: .outline) {}
        }

        HStack(spacing: 12) {
            GlassIconButton(icon: "heart.fill", color: .red) {}
            GlassIconButton(icon: "star.fill", color: .yellow) {}
            GlassIconButton(icon: "bookmark.fill", color: .blue) {}
        }

        // Badge
        HStack {
            Text("Notifications")
            Spacer()
            GlassBadge(count: 5)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)

        // Progress
        GlassProgress(value: 0.7, color: .green)
            .frame(width: 200)

        // Tooltip
        GlassTooltip("Press ⌘+Shift+5 to capture", icon: "keyboard")
    }
    .padding(24)
    .frame(width: 400)
}
