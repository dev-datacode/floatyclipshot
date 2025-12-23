//
//  ToastView.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Toast notification component for displaying feedback messages
//

import SwiftUI

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let type: ScreenshotManager.ToastType

    private var icon: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var color: Color {
        switch type {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "Screenshot captured!", type: .success)
        ToastView(message: "Failed to capture", type: .error)
        ToastView(message: "Copied to clipboard", type: .info)
    }
    .padding()
}
