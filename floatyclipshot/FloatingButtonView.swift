//
//  FloatingButtonView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//
//  Main floating capture button with visual feedback and context menu
//

import Foundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

struct FloatingButtonView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var notesManager = NotesManager.shared
    @ObservedObject private var tagManager = TagManager.shared
    @ObservedObject private var screenshotManager = ScreenshotManager.shared
    
    @State private var showCaptureAnimation = false
    @State private var showGlassyFeedback = false
    @State private var showCheckmark = false
    @State private var isAnimating = false
    
    // UI State for sheets/popovers
    @State private var showHotkeyRecorder = false
    @State private var showPasteHotkeyRecorder = false
    @State private var showStorageSettings = false
    @State private var showQuickNote = false
    @State private var showNotesList = false
    @State private var showPermissionsView = false
    @State private var showTagEditor = false
    @State private var showTagList = false
    @State private var showPairingList = false
    
    @State private var windowToTag: WindowInfo?
    @State private var missingPermissions = false
    @State private var lastClickTime: Date = .distantPast  // For click debouncing
    @State private var showFloatingMenu = false
    @State private var selectedMenuTab = 0

    // Hover state for Liquid Glass expansion
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var isDragTarget = false // For drop zone feedback

    // MARK: - Computed Properties for Liquid Glass

    private var buttonSize: CGFloat {
        if isDragTarget { return 64 } // Expand when dragging over
        return isHovered ? 56 : 50
    }

    private var captureCount: Int {
        clipboardManager.clipboardHistory.prefix(99).count
    }

    var body: some View {
        ZStack {
            // MARK: - Button Base
            Capsule()
                .fill(isDragTarget ? Color.green.opacity(0.8) : Color(nsColor: .controlBackgroundColor).opacity(0.9)) // Visual feedback
                .frame(width: isHovered ? 110 : buttonSize, height: buttonSize)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                .overlay(
                    Capsule()
                        .strokeBorder(isDragTarget ? Color.white : Color.white.opacity(0.3), lineWidth: isDragTarget ? 2 : 1)
                )
                .scaleEffect(isPressed ? 0.92 : (showCaptureAnimation ? 0.9 : 1.0))

            // MARK: - Button Content
            HStack(spacing: isHovered ? 8 : 0) {
                // Main icon
                Image(systemName: isDragTarget ? "arrow.down.doc.fill" : buttonIcon) // Change icon on drag
                    .font(.system(size: isHovered ? 16 : 18, weight: .semibold))
                    .foregroundStyle(.white)

                // Expanded quick actions (shown on hover)
                if isHovered && !isDragTarget {
                    expandedActionsView
                }
            }

            // MARK: - Badges
            if captureCount > 0 && !isHovered && !isDragTarget {
                CaptureCountBadge(count: captureCount, color: badgeColor)
            }

            if missingPermissions && !isHovered && !isDragTarget {
                PermissionWarningBadge()
            }

            // MARK: - Feedback
            GlassyRipple(isVisible: showGlassyFeedback, size: buttonSize)
            SuccessCheckmark(isVisible: showCheckmark)
        }
        .padding(8)
        .contentShape(Capsule())
        .onDrop(of: [.fileURL, .text, .url, .image], isTargeted: $isDragTarget) { providers in
            Task {
                await DropHandler.shared.handleDrop(providers)
            }
            return true
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .animation(.easeOut(duration: 0.15), value: showCaptureAnimation)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showCheckmark)
        .animation(.easeOut(duration: 0.4), value: showGlassyFeedback)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onTapGesture {
            handleTap()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerCaptureAnimation"))) { _ in
            triggerCaptureAnimation()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            updateStatus()
        }
        .onAppear {
            windowManager.refreshWindowList()
            updateStatus()
        }
        .help(tooltipText)
        .onLongPressGesture(minimumDuration: 0.3) {
            MainPanelController.shared.show()
        }
        .contextMenu {
            ButtonMainContextMenu(
                windowToTag: $windowToTag,
                showTagEditor: $showTagEditor,
                showPermissionsView: $showPermissionsView
            )
        }
        .sheet(isPresented: $showHotkeyRecorder) { HotkeyRecorderView() }
        .sheet(isPresented: $showPasteHotkeyRecorder) { PasteHotkeyRecorderView() }
        .sheet(isPresented: $showStorageSettings) { StorageSettingsView() }
        .sheet(isPresented: $showQuickNote) { QuickNoteView() }
        .sheet(isPresented: $showNotesList) { NotesListView() }
        .sheet(isPresented: $showPermissionsView) { PermissionsView() }
        .sheet(isPresented: $showTagList) { TagListView() }
        .sheet(isPresented: $showPairingList) { PairingListView() }
        .sheet(isPresented: $showTagEditor) {
            if let window = windowToTag {
                TagEditorView(window: window)
            }
        }
        .onChange(of: screenshotManager.showQuickPicker) { _, showPicker in
            if showPicker {
                QuickPickerWindowController.shared.show(targets: screenshotManager.quickPickerTargets)
            } else {
                QuickPickerWindowController.shared.close()
            }
        }
        .overlay(alignment: .top) {
            if let message = screenshotManager.toastMessage {
                ToastView(message: message, type: screenshotManager.toastType)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.spring(response: 0.3), value: screenshotManager.toastMessage)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var expandedActionsView: some View {
        HStack(spacing: 6) {
            Button(action: performQuickCapture) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 16)

            Button(action: { FloatingMenuController.shared.show() }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .help("Quick Menu")
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }

    // MARK: - Logic

    private func handleTap() {
        if missingPermissions {
            showPermissionsView = true
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastClickTime) > 0.3 else { return }
        lastClickTime = now

        performQuickCapture()
    }

    private func updateStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            checkPermissions()
            screenshotManager.updateAutoPairingStatus()
        }
    }

    private func checkPermissions() {
        let accessibility = ScreenshotManager.shared.isAccessibilityGranted()
        let screenRecording = ScreenshotManager.shared.isScreenRecordingGranted()
        withAnimation {
            missingPermissions = !accessibility || !screenRecording
        }
    }

    private func performQuickCapture() {
        triggerCaptureAnimation()
        ScreenshotManager.shared.captureFullScreen()
    }

    private func triggerCaptureAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        showCaptureAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCaptureAnimation = false
        }

        showGlassyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            showGlassyFeedback = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showCheckmark = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            showCheckmark = false
            self.isAnimating = false
        }
    }

    // MARK: - Computed Styles

    private var badgeColor: Color {
        if captureCount >= 50 { return .orange }
        if captureCount >= 20 { return .blue }
        return .secondary
    }

    private var buttonIcon: String {
        if clipboardManager.isPaused { return "eye.slash.fill" }
        if windowManager.selectedWindow != nil { return "scope" }

        switch screenshotManager.autoPairingStatus {
        case .paired: return "link.circle.fill"
        case .ready: return "iphone"
        case .multiple: return "square.stack.3d.up"
        case .none: return "camera.fill"
        }
    }

    private var tooltipText: String {
        if clipboardManager.isPaused {
            return "Private Mode Active\nClipboard monitoring paused\nRight-click: Options"
        }
        if let window = windowManager.selectedWindow {
            return "Click: Capture \(window.displayName)\nRight-click: Options"
        }
        switch screenshotManager.autoPairingStatus {
        case .paired: return "Click: Capture paired target\nRight-click: Options"
        case .ready: return "Click: Capture simulator\nRight-click: Options"
        case .multiple: return "Click: Select from simulators\nRight-click: Options"
        case .none: return "Click: Capture Full Screen\nRight-click: Choose Window"
        }
    }
}

// MARK: - Context Menu Component

struct ButtonMainContextMenu: View {
    @Binding var windowToTag: WindowInfo?
    @Binding var showTagEditor: Bool
    @Binding var showPermissionsView: Bool
    
    var body: some View {
        Group {
            Button(action: { FloatingMenuController.shared.show() }) {
                Label("Quick Menu", systemImage: "square.grid.2x2")
            }

            Button(action: { MainPanelController.shared.show() }) {
                Label("Open Full Panel", systemImage: "macwindow")
            }

            Divider()

            Button(action: { ScreenshotManager.shared.captureFullScreen() }) {
                Label("Capture Now", systemImage: "camera.fill")
            }

            Button(action: { ScreenshotManager.shared.captureAndPaste() }) {
                Label("Capture & Paste", systemImage: "doc.on.clipboard")
            }

            Divider()

            // Quick window selection
            Menu("Select Window") {
                Button("Full Screen") { WindowManager.shared.clearSelection() }
                Divider()
                ForEach(WindowManager.shared.availableWindows.prefix(10)) { window in
                    Button(window.displayName) { WindowManager.shared.selectWindow(window) }
                }
            }

            Divider()

            QuickPairMenu()

            Divider()

            PrivateModeToggleButton(compact: false)

            Button(action: { SecuritySettingsWindowController.shared.showWindow() }) {
                Label("Security Settings...", systemImage: "lock.shield")
            }

            Divider()

            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

struct QuickPairMenu: View {
    var body: some View {
        Menu("Quick Pair") {
            let allWindows = WindowManager.shared.availableWindows.filter {
                !$0.ownerName.contains("floatyclipshot") && !$0.ownerName.contains("FloatingScreenshot")
            }

            if allWindows.isEmpty {
                Text("No windows found")
            } else {
                ForEach(allWindows.prefix(15)) { target in
                    Button(action: {
                        if let sourceWindow = ScreenshotManager.shared.getActiveSourceWindow() {
                            PairingManager.shared.createPairing(from: sourceWindow, to: target, pasteMode: .auto)
                        }
                    }) {
                        Label(target.name.isEmpty ? target.ownerName : "\(target.ownerName): \(String(target.name.prefix(30)))",
                              systemImage: targetIcon(for: target))
                    }
                }
            }

            Divider()
            Button(action: { WindowManager.shared.forceRefreshWindowList() }) {
                Label("Refresh Window List", systemImage: "arrow.clockwise")
            }
        }
    }
    
    private func targetIcon(for target: WindowInfo) -> String {
        switch target.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome", "Chrome": return "globe"
        case "Terminal", "iTerm2": return "terminal"
        case "Xcode", "Code", "Cursor": return "chevron.left.forwardslash.chevron.right"
        default: return "macwindow"
        }
    }
}