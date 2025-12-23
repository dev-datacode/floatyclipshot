//
//  AnimatedTransitions.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Reusable animation transitions and view modifiers for Liquid Glass UI
//

import SwiftUI

// MARK: - Custom Transitions

extension AnyTransition {
    /// Smooth scale and fade transition
    static var glassAppear: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }

    /// Slide from bottom with fade
    static var glassSlideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// Slide from top with fade
    static var glassSlideDown: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    /// Expand from center
    static var glassExpand: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        )
    }

    /// Blur transition
    static func glassBlur(radius: CGFloat = 10) -> AnyTransition {
        .modifier(
            active: BlurModifier(radius: radius, opacity: 0),
            identity: BlurModifier(radius: 0, opacity: 1)
        )
    }
}

// MARK: - Blur Modifier

private struct BlurModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
    }
}

// MARK: - Hover Effect Modifier

/// Adds interactive hover effect to any view
struct HoverEffectModifier: ViewModifier {
    let scaleAmount: CGFloat
    let brightnessAmount: Double

    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scaleAmount : 1.0)
            .brightness(isHovered ? brightnessAmount : 0)
            .animation(GlassDesign.Animation.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    /// Apply hover effect with scale and brightness
    func glassHover(scale: CGFloat = 1.02, brightness: Double = 0.05) -> some View {
        modifier(HoverEffectModifier(scaleAmount: scale, brightnessAmount: brightness))
    }
}

// MARK: - Press Effect Modifier

/// Adds press feedback effect to any view
struct PressEffectModifier: ViewModifier {
    let scaleAmount: CGFloat

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scaleAmount : 1.0)
            .animation(GlassDesign.Animation.quick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    /// Apply press feedback effect
    func glassPress(scale: CGFloat = 0.95) -> some View {
        modifier(PressEffectModifier(scaleAmount: scale))
    }
}

// MARK: - Shimmer Effect

/// Shimmer effect - disabled due to macOS 26 beta animation bugs
struct ShimmerEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        content // Shimmer animation disabled for stability
    }
}

extension View {
    /// Apply shimmer loading effect (disabled for stability)
    func glassShimmer() -> some View {
        self // Disabled due to macOS 26 beta repeatForever animation bugs
    }
}

// MARK: - Pulse Effect

/// Pulse effect - disabled due to macOS 26 beta animation bugs
struct PulseEffectModifier: ViewModifier {
    let color: Color
    let duration: Double

    func body(content: Content) -> some View {
        content // Pulse animation disabled for stability
    }
}

extension View {
    /// Apply pulse attention effect (disabled for stability)
    func glassPulse(color: Color = .blue, duration: Double = 1.5) -> some View {
        self // Disabled due to macOS 26 beta repeatForever animation bugs
    }
}

// MARK: - Appear Animation Modifier

/// Animates view appearance with delay support
struct AppearAnimationModifier: ViewModifier {
    let animation: Animation
    let delay: Double

    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.9)
            .offset(y: hasAppeared ? 0 : 10)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(animation) {
                        hasAppeared = true
                    }
                }
            }
    }
}

extension View {
    /// Animate view appearance with optional delay
    func glassAppearAnimation(
        animation: Animation = GlassDesign.Animation.smooth,
        delay: Double = 0
    ) -> some View {
        modifier(AppearAnimationModifier(animation: animation, delay: delay))
    }
}

// MARK: - Staggered Animation

/// Container for staggered child animations
struct StaggeredAnimationContainer<Content: View>: View {
    let baseDelay: Double
    let staggerDelay: Double
    let content: Content

    init(
        baseDelay: Double = 0,
        staggerDelay: Double = 0.05,
        @ViewBuilder content: () -> Content
    ) {
        self.baseDelay = baseDelay
        self.staggerDelay = staggerDelay
        self.content = content()
    }

    var body: some View {
        content
    }
}

// MARK: - Content Transition Helpers

extension View {
    /// Smooth symbol replacement transition (simplified for stability)
    func glassSymbolTransition() -> some View {
        self // Removed .contentTransition(.symbolEffect) due to macOS 26 beta bugs
    }

    /// Numeric content transition
    func glassNumericTransition() -> some View {
        self // Removed .contentTransition(.numericText()) due to macOS 26 beta bugs
    }
}

// MARK: - Conditional Animation

extension View {
    /// Apply animation only when condition is met
    @ViewBuilder
    func animateIf(_ condition: Bool, animation: Animation = GlassDesign.Animation.standard) -> some View {
        if condition {
            self.animation(animation, value: condition)
        } else {
            self
        }
    }
}

// MARK: - Spring Presets

extension Animation {
    /// Snappy spring for quick interactions
    static var glassSnappy: Animation {
        .spring(response: 0.25, dampingFraction: 0.8)
    }

    /// Smooth spring for larger movements
    static var glassSmooth: Animation {
        .spring(response: 0.4, dampingFraction: 0.85)
    }

    /// Bouncy spring for playful feedback
    static var glassBouncy: Animation {
        .spring(response: 0.35, dampingFraction: 0.65)
    }

    /// Gentle spring for subtle effects
    static var glassGentle: Animation {
        .spring(response: 0.5, dampingFraction: 0.9)
    }
}

// MARK: - Preview

#Preview("Animated Transitions") {
    VStack(spacing: 24) {
        // Hover effect
        Text("Hover Me")
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
            .glassHover()

        // Press effect
        Text("Press Me")
            .padding()
            .background(Color.green.opacity(0.2))
            .cornerRadius(8)
            .glassPress()

        // Pulse effect
        Circle()
            .fill(.red)
            .frame(width: 20, height: 20)
            .glassPulse(color: .red)

        // Appear animation with stagger
        VStack(spacing: 8) {
            ForEach(0..<3) { index in
                Text("Item \(index + 1)")
                    .padding()
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(8)
                    .glassAppearAnimation(delay: Double(index) * 0.1)
            }
        }
    }
    .padding(24)
    .frame(width: 300)
}
