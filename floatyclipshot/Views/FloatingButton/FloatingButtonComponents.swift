//
//  FloatingButtonComponents.swift
//  floatyclipshot
//

import SwiftUI
import AppKit

// MARK: - Capture Count Badge

struct CaptureCountBadge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background {
                        Capsule()
                            .fill(color)
                    }
                    .offset(x: 6, y: -6)
            }
            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Warning Badge

struct PermissionWarningBadge: View {
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background {
                        Circle()
                            .fill(.red)
                    }
                    .offset(x: 6, y: -6)
            }
            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Success Checkmark

struct SuccessCheckmark: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.green)
                .scaleEffect(isVisible ? 1.0 : 0.5)
                .opacity(isVisible ? 1 : 0)
        }
    }
}

// MARK: - Ripple Feedback

struct GlassyRipple: View {
    let isVisible: Bool
    let size: CGFloat
    
    var body: some View {
        if isVisible {
            Capsule()
                .fill(Color.white.opacity(0.4))
                .frame(width: size, height: size)
                .scaleEffect(isVisible ? 1.5 : 0.8)
                .opacity(isVisible ? 0 : 0.6)
        }
    }
}
