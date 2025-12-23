//
//  QuickPickerView.swift
//  floatyclipshot
//
//  Quick picker overlay for selecting from multiple simulators/targets
//  Shows when Cmd+Shift+B is pressed with multiple targets on screen
//

import SwiftUI
import AppKit

struct QuickPickerView: View {
    @ObservedObject var screenshotManager = ScreenshotManager.shared
    @Environment(\.dismiss) var dismiss

    // Keyboard monitoring
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("Select Target")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text("ESC to cancel")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider().opacity(0.5)

            // Target list
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(screenshotManager.quickPickerTargets.enumerated()), id: \.element.id) { index, target in
                        QuickPickerRow(
                            target: target,
                            shortcut: index < 9 ? "\(index + 1)" : nil,
                            onSelect: {
                                selectTarget(target)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 300)

            Divider().opacity(0.5)

            // Footer hint
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text("Press 1-9 to quick select, or click")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 320)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    private func selectTarget(_ target: WindowInfo) {
        screenshotManager.showQuickPicker = false
        screenshotManager.captureWithTarget(target, andCreatePairing: true)
        dismiss()
    }

    private func setupKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ESC to cancel
            if event.keyCode == 53 {
                screenshotManager.showQuickPicker = false
                dismiss()
                return nil
            }

            // Number keys 1-9 for quick selection
            if let characters = event.characters,
               let number = Int(characters),
               number >= 1 && number <= 9 {
                let index = number - 1
                if index < screenshotManager.quickPickerTargets.count {
                    selectTarget(screenshotManager.quickPickerTargets[index])
                    return nil
                }
            }

            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

struct QuickPickerRow: View {
    let target: WindowInfo
    let shortcut: String?
    let onSelect: () -> Void

    @State private var isHovered = false

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
        // Truncate long names
        let name = target.name
        if name.count > 40 {
            return String(name.prefix(40)) + "..."
        }
        return name
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Shortcut badge
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(iconColor)
                        }
                }

                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !target.name.isEmpty {
                        Text(target.ownerName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Capture button (visible on hover)
                if isHovered {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? iconColor.opacity(0.15) : Color.primary.opacity(0.03))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Quick Picker Window Controller

class QuickPickerWindowController {
    static let shared = QuickPickerWindowController()

    private var window: NSWindow?
    private var clickMonitor: Any?

    func show(targets: [WindowInfo]) {
        // Close existing window and cleanup
        close()

        // Create new window
        let pickerView = QuickPickerView()
        let hostingController = NSHostingController(rootView: pickerView)

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.styleMask = [.borderless]
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true
        newWindow.level = .floating
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Center on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = newWindow.frame.size
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.midY - windowSize.height / 2 + 100 // Slightly above center
            newWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)

        // Auto-close when clicking outside
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let window = self?.window,
               !window.frame.contains(NSEvent.mouseLocation) {
                self?.close()
            }
            return event
        }
    }

    func close() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        
        window?.orderOut(nil)
        window = nil
        
        // Ensure state is updated on main thread
        Task { @MainActor in
            ScreenshotManager.shared.showQuickPicker = false
        }
    }
}

#Preview {
    QuickPickerView()
        .frame(width: 350, height: 400)
}
