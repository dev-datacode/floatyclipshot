//
//  FloatingButtonView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import Foundation
import SwiftUI
import AppKit
import Combine

struct FloatingButtonView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @ObservedObject private var notesManager = NotesManager.shared
    @ObservedObject private var tagManager = TagManager.shared
    @State private var showCaptureAnimation = false
    @State private var showGlassyFeedback = false
    @State private var showCheckmark = false
    @State private var isAnimating = false
    @State private var showHotkeyRecorder = false
    @State private var showPasteHotkeyRecorder = false
    @State private var showStorageSettings = false
    @State private var showQuickNote = false
    @State private var showNotesList = false
    @State private var showPermissionsView = false
    @State private var showTagEditor = false
    @State private var showTagList = false
    @State private var windowToTag: WindowInfo?
    @State private var missingPermissions = false
    @State private var lastClickTime: Date = .distantPast  // For click debouncing
    @State private var showFloatingMenu = false
    @State private var selectedMenuTab = 0

    // Check permissions periodically
    let permissionTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Main button
            Circle()
                .fill(buttonColor)
                .frame(width: 50, height: 50)
                .shadow(radius: 8)
                .scaleEffect(showCaptureAnimation ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: showCaptureAnimation)

            // Button icon
            Image(systemName: buttonIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                
            // Warning Badge for Missing Permissions
            if missingPermissions {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(Color.red))
                            .offset(x: 4, y: -4)
                    }
                    Spacer()
                }
            }

            // Apple-like glassy feedback overlay
            if showGlassyFeedback {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .scaleEffect(showGlassyFeedback ? 1.5 : 0.5)
                    .opacity(showGlassyFeedback ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: showGlassyFeedback)
                    .blur(radius: 8)
            }

            // Success checkmark
            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: showCheckmark)
            }
        }
        .padding(8)
        .contentShape(Circle()) // Make entire circle clickable
        .onTapGesture {
            // If permissions missing, show permissions view instead of capturing
            if missingPermissions {
                showPermissionsView = true
                return
            }
            
            // Debounce: Ignore clicks within 300ms to prevent accidental double-screenshots
            let now = Date()
            guard now.timeIntervalSince(lastClickTime) > 0.3 else {
                print("⚠️ Click too fast, ignoring (debounced)")
                return
            }
            lastClickTime = now

            // Primary action: Instant capture!
            performQuickCapture()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerCaptureAnimation"))) { _ in
            // Triggered by keyboard shortcut
            triggerCaptureAnimation()
        }
        .onReceive(permissionTimer) { _ in
            checkPermissions()
        }
        .onAppear {
            // FIX: Refresh window list when app launches to populate initial list
            windowManager.refreshWindowList()
            checkPermissions()
        }
        .help(tooltipText)
        .onLongPressGesture(minimumDuration: 0.3) {
            showFloatingMenu = true
            windowManager.refreshWindowList()
        }
        .gesture(
            TapGesture(count: 1)
                .simultaneously(with: TapGesture(count: 1))
                .onEnded { _ in }
        )
        .popover(isPresented: $showFloatingMenu, arrowEdge: .bottom) {
            FloatingMenuView(
                showFloatingMenu: $showFloatingMenu,
                showTagEditor: $showTagEditor,
                showTagList: $showTagList,
                showHotkeyRecorder: $showHotkeyRecorder,
                showPasteHotkeyRecorder: $showPasteHotkeyRecorder,
                showStorageSettings: $showStorageSettings,
                showQuickNote: $showQuickNote,
                showNotesList: $showNotesList,
                showPermissionsView: $showPermissionsView,
                windowToTag: $windowToTag,
                missingPermissions: missingPermissions
            )
        }
        .contextMenu {
            // Simple fallback context menu
            Button(action: {
                showFloatingMenu = true
                windowManager.refreshWindowList()
            }) {
                Label("Open Menu", systemImage: "square.grid.2x2")
            }

            Divider()

            Button(action: { performQuickCapture() }) {
                Label("Capture Now", systemImage: "camera.fill")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .sheet(isPresented: $showHotkeyRecorder) {
            HotkeyRecorderView()
        }
        .sheet(isPresented: $showPasteHotkeyRecorder) {
            PasteHotkeyRecorderView()
        }
        .sheet(isPresented: $showStorageSettings) {
            StorageSettingsView()
        }
        .sheet(isPresented: $showQuickNote) {
            QuickNoteView()
        }
        .sheet(isPresented: $showNotesList) {
            NotesListView()
        }
        .sheet(isPresented: $showPermissionsView) {
            PermissionsView()
        }
        .sheet(isPresented: $showTagEditor) {
            if let window = windowToTag {
                TagEditorView(window: window)
            }
        }
        .sheet(isPresented: $showTagList) {
            TagListView()
        }
    }
    
    // Check system permissions
    private func checkPermissions() {
        let accessibility = ScreenshotManager.shared.isAccessibilityGranted()
        let screenRecording = ScreenshotManager.shared.isScreenRecordingGranted()
        
        // If either is missing, show warning
        withAnimation {
            missingPermissions = !accessibility || !screenRecording
        }
    }

    // Instant capture with visual feedback
    private func performQuickCapture() {
        triggerCaptureAnimation()
        // Capture to clipboard instantly
        ScreenshotManager.shared.captureFullScreen()
    }

    // Smooth Apple-like capture animation (for keyboard shortcut feedback)
    private func triggerCaptureAnimation() {
        // Prevent overlapping animations
        guard !isAnimating else { return }
        isAnimating = true

        // Button squeeze
        showCaptureAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showCaptureAnimation = false
        }

        // Glassy feedback - starts immediately and expands/fades out
        showGlassyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Trigger the expansion/fade animation
            showGlassyFeedback = false
        }

        // Success checkmark - appears with spring animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showCheckmark = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            showCheckmark = false
            // Release animation lock after animation completes
            self.isAnimating = false
        }
    }

    // Window selection section
    @ViewBuilder
    private var windowSelectionSection: some View {
        // Show current selection prominently
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Target:")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(windowManager.selectionDisplayText)
                .font(.body)
                .bold()
        }

        Divider()

        // Window picker with auto-refresh
        Menu("Choose Window Target") {
            // Option to capture full screen
            Button(action: {
                windowManager.clearSelection()
            }) {
                Label("🖥️ Full Screen (All Displays)", systemImage: windowManager.selectedWindow == nil ? "checkmark" : "")
            }

            if !windowManager.availableWindows.isEmpty {
                Divider()

                ForEach(windowManager.availableWindows) { window in
                    Menu {
                        // Select window action
                        Button(action: {
                            windowManager.selectWindow(window)
                        }) {
                            Label("Select", systemImage: "scope")
                        }

                        Divider()

                        // Tag actions
                        if let tag = tagManager.tagForWindow(window) {
                            Button(action: {
                                // Delay to let menu close first
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    windowToTag = window
                                    showTagEditor = true
                                }
                            }) {
                                Label("Edit Tag", systemImage: "pencil")
                            }

                            Button(role: .destructive, action: {
                                tagManager.deleteTag(tag)
                            }) {
                                Label("Remove Tag", systemImage: "trash")
                            }
                        } else {
                            Button(action: {
                                // Delay to let menu close first
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    windowToTag = window
                                    showTagEditor = true
                                }
                            }) {
                                Label("Add Tag", systemImage: "tag.fill")
                            }

                            // Quick tag with color (no editor needed)
                            Menu("Quick Tag") {
                                ForEach(TagColor.allCases) { color in
                                    Button(action: {
                                        let tag = WindowTag(
                                            projectName: window.ownerName,
                                            tagColor: color,
                                            ownerName: window.ownerName,
                                            windowNamePattern: window.name
                                        )
                                        tagManager.addTag(tag)
                                    }) {
                                        Label(color.displayName, systemImage: "circle.fill")
                                            .foregroundColor(color.color)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            // Tag color indicator
                            if let tag = tagManager.tagForWindow(window) {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(tag.tagColor.color)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.3))
                            }

                            // Checkmark if selected
                            if windowManager.selectedWindow?.id == window.id {
                                Image(systemName: "checkmark")
                            }

                            Text(windowDisplayText(for: window))
                        }
                    }
                }
            }
        }
        .onAppear {
            // Auto-refresh when menu opens
            windowManager.refreshWindowList()
        }

        Button("Refresh Window List") {
            windowManager.refreshWindowList()
        }
    }

    // Window tagging section
    @ViewBuilder
    private var windowTaggingSection: some View {
        // Window Tags submenu
        Menu("Window Tags \(tagManager.tags.isEmpty ? "" : "(\(tagManager.tags.count))")") {
            // Toggle tags visibility
            Toggle(isOn: $tagManager.isEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Tags")
                        .font(.body)
                    Text(tagManager.isEnabled ? "Tags visible on windows" : "Tags hidden")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Tag current window (if one is selected)
            if let selectedWindow = windowManager.selectedWindow {
                if let tag = tagManager.tagForWindow(selectedWindow) {
                    // Show existing tag info
                    Text("Tagged: \(tag.projectName)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        windowToTag = selectedWindow
                        showTagEditor = true
                    }) {
                        Label("Edit Tag...", systemImage: "pencil")
                    }

                    Button(role: .destructive, action: {
                        tagManager.deleteTag(tag)
                    }) {
                        Label("Remove Tag", systemImage: "trash")
                    }
                } else {
                    Button(action: {
                        windowToTag = selectedWindow
                        showTagEditor = true
                    }) {
                        Label("Tag \"\(selectedWindow.ownerName)\"...", systemImage: "tag.fill")
                    }
                }

                Divider()
            }

            // Quick tag any window
            Menu("Tag a Window...") {
                ForEach(windowManager.availableWindows) { window in
                    Button(action: {
                        windowToTag = window
                        showTagEditor = true
                    }) {
                        Label {
                            Text(windowDisplayText(for: window))
                        } icon: {
                            if let tag = tagManager.tagForWindow(window) {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(tag.tagColor.color)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.clear)
                            }
                        }
                    }
                }
            }

            Divider()

            // Manage all tags
            Button(action: { showTagList = true }) {
                Label("Manage Tags...", systemImage: "tag.square")
            }
        }
    }

    // Helper to show window name with tag project name
    private func windowDisplayText(for window: WindowInfo) -> String {
        if let tag = tagManager.tagForWindow(window) {
            return "[\(tag.projectName)] \(window.displayName)"
        }
        return window.displayName
    }

    // Dynamic button color based on window selection
    private var buttonColor: Color {
        if windowManager.selectedWindow != nil {
            return Color.green.opacity(0.85) // Green = targeted capture ready
        }
        return Color.black.opacity(0.7) // Black = full screen
    }

    // Dynamic icon based on window selection
    private var buttonIcon: String {
        if windowManager.selectedWindow != nil {
            return "scope" // Crosshair = targeted
        }
        return "camera.fill" // Camera = full screen
    }

    // Tooltip text
    private var tooltipText: String {
        if let window = windowManager.selectedWindow {
            return "Click: Capture \(window.displayName)\nRight-click: Options"
        }
        return "Click: Capture Full Screen\nRight-click: Choose Window"
    }

    // Storage usage text and color
    private var storageUsageText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        let usedString = formatter.string(fromByteCount: clipboardManager.totalStorageUsed)

        let limit = SettingsManager.shared.storageLimit
        if limit.isUnlimited {
            return "\(usedString) used • Unlimited"
        } else {
            let limitString = formatter.string(fromByteCount: limit.bytes)
            let percentage = Int((Double(clipboardManager.totalStorageUsed) / Double(limit.bytes)) * 100)
            return "\(usedString) / \(limitString) (\(percentage)%)"
        }
    }

    private var storageUsageColor: Color {
        let limit = SettingsManager.shared.storageLimit
        guard !limit.isUnlimited else { return .secondary }

        let percentage = Double(clipboardManager.totalStorageUsed) / Double(limit.bytes)

        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return .secondary
        }
    }
}

#Preview {
    FloatingButtonView()
        .frame(width: 100, height: 100)
        .background(Color.gray.opacity(0.3))
}

// MARK: - Creative Floating Menu

struct FloatingMenuView: View {
    @Binding var showFloatingMenu: Bool
    @Binding var showTagEditor: Bool
    @Binding var showTagList: Bool
    @Binding var showHotkeyRecorder: Bool
    @Binding var showPasteHotkeyRecorder: Bool
    @Binding var showStorageSettings: Bool
    @Binding var showQuickNote: Bool
    @Binding var showNotesList: Bool
    @Binding var showPermissionsView: Bool
    @Binding var windowToTag: WindowInfo?
    var missingPermissions: Bool

    @State private var selectedTab = 0
    @State private var hoveredWindow: Int?

    // Local copies to avoid crashes from ObservedObject updates during view lifecycle
    @State private var cachedWindows: [WindowInfo] = []
    @State private var cachedClipboardItems: [ClipboardItem] = []
    @State private var cachedIsPaused: Bool = false
    @State private var cachedHotkeyEnabled: Bool = false
    @State private var cachedHotkeyString: String = ""
    @State private var cachedSelectedWindow: WindowInfo?

    private let tabs = ["Windows", "Clipboard", "Settings"]
    private let tabIcons = ["macwindow.on.rectangle", "doc.on.clipboard", "gearshape"]

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: { withAnimation(.spring(response: 0.3)) { selectedTab = index } }) {
                        VStack(spacing: 4) {
                            Image(systemName: tabIcons[index])
                                .font(.system(size: 16, weight: selectedTab == index ? .semibold : .regular))
                            Text(tabs[index])
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == index ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selectedTab == index {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.ultraThinMaterial)
                                    .glassEffect()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial.opacity(0.5))

            Divider().opacity(0.5)

            // Content
            ScrollView {
                VStack(spacing: 8) {
                    switch selectedTab {
                    case 0: windowsTab
                    case 1: clipboardTab
                    case 2: settingsTab
                    default: windowsTab
                    }
                }
                .padding(12)
            }
            .frame(height: 280)

            Divider().opacity(0.5)

            // Footer
            HStack {
                Button(action: { showFloatingMenu = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    showFloatingMenu = false
                    ScreenshotManager.shared.captureFullScreen()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text("Capture")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(.blue)
                            .glassEffect()
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .frame(width: 300)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .glassEffect()
        }
        .onAppear {
            refreshCache()
        }
    }

    private func refreshCache() {
        // Safely copy data to avoid crashes from ObservedObject updates
        cachedWindows = Array(WindowManager.shared.availableWindows)  // All windows
        cachedClipboardItems = Array(ClipboardManager.shared.clipboardHistory.prefix(5))
        cachedIsPaused = ClipboardManager.shared.isPaused
        cachedHotkeyEnabled = HotkeyManager.shared.isEnabled
        cachedHotkeyString = HotkeyManager.shared.hotkeyDisplayString
        cachedSelectedWindow = WindowManager.shared.selectedWindow
    }

    private func refreshWindows() {
        WindowManager.shared.refreshWindowList()
        // Small delay to let the refresh complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cachedWindows = Array(WindowManager.shared.availableWindows)
            cachedSelectedWindow = WindowManager.shared.selectedWindow
        }
    }

    // MARK: - Windows Tab
    @ViewBuilder
    private var windowsTab: some View {
        // Current target
        MenuCard(icon: "scope", title: "Target", subtitle: cachedSelectedWindow?.displayName ?? "Full Screen") {
            if cachedSelectedWindow != nil {
                Button(action: {
                    WindowManager.shared.clearSelection()
                    cachedSelectedWindow = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }

        // Header with count and refresh
        HStack {
            Text("\(cachedWindows.count) windows")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: refreshWindows) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text("Refresh")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)

        // Windows list - ALL windows
        VStack(spacing: 4) {
            ForEach(cachedWindows) { window in
                WindowRow(
                    window: window,
                    isSelected: cachedSelectedWindow?.id == window.id,
                    tag: TagManager.shared.tagForWindow(window),
                    isHovered: hoveredWindow == window.id,
                    onSelect: {
                        WindowManager.shared.selectWindow(window)
                        showFloatingMenu = false
                    },
                    onTag: {
                        windowToTag = window
                        showFloatingMenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showTagEditor = true
                        }
                    }
                )
                .onHover { hovering in
                    hoveredWindow = hovering ? window.id : nil
                }
            }
        }

        // Manage tags button
        MenuButton(icon: "tag.square.fill", title: "Manage Tags", color: .purple) {
            showFloatingMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showTagList = true
            }
        }
    }

    // MARK: - Clipboard Tab
    @ViewBuilder
    private var clipboardTab: some View {
        // Status card
        MenuCard(
            icon: cachedIsPaused ? "pause.circle.fill" : "play.circle.fill",
            title: "Clipboard Monitor",
            subtitle: cachedIsPaused ? "Paused" : "Active"
        ) {
            Toggle("", isOn: Binding(
                get: { !cachedIsPaused },
                set: { newValue in
                    ClipboardManager.shared.isPaused = !newValue
                    cachedIsPaused = !newValue
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.7)
        }

        // Recent items
        if !cachedClipboardItems.isEmpty {
            VStack(spacing: 4) {
                ForEach(cachedClipboardItems) { item in
                    ClipboardItemRow(item: item) {
                        ClipboardManager.shared.pasteItem(item)
                        showFloatingMenu = false
                    }
                }
            }

            MenuButton(icon: "clock.arrow.circlepath", title: "View All History", color: .orange) {
                showFloatingMenu = false
                WindowManager.shared.showHistoryWindow()
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "clipboard")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No clipboard history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }

        // Quick Note
        MenuButton(icon: "note.text.badge.plus", title: "Add Quick Note", color: .yellow) {
            showFloatingMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showQuickNote = true
            }
        }
    }

    // MARK: - Settings Tab
    @ViewBuilder
    private var settingsTab: some View {
        if missingPermissions {
            MenuButton(icon: "exclamationmark.triangle.fill", title: "Fix Permissions", color: .red) {
                showFloatingMenu = false
                showPermissionsView = true
            }
        }

        // Hotkeys
        MenuCard(icon: "keyboard", title: "Capture Hotkey", subtitle: cachedHotkeyEnabled ? cachedHotkeyString : "Disabled") {
            Toggle("", isOn: Binding(
                get: { cachedHotkeyEnabled },
                set: { newValue in
                    HotkeyManager.shared.isEnabled = newValue
                    cachedHotkeyEnabled = newValue
                }
            ))
            .toggleStyle(.switch)
            .scaleEffect(0.7)
        }

        MenuButton(icon: "keyboard.badge.ellipsis", title: "Change Hotkeys...", color: .blue) {
            showFloatingMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showHotkeyRecorder = true
            }
        }

        // Storage
        MenuButton(icon: "externaldrive.fill", title: "Storage Settings", color: .gray) {
            showFloatingMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showStorageSettings = true
            }
        }

        Spacer()

        // Quit
        MenuButton(icon: "power", title: "Quit", color: .red) {
            NSApplication.shared.terminate(nil)
        }
    }
}

// MARK: - Menu Components

struct MenuCard<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 28)

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
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .glassEffect()
        }
    }
}

struct MenuButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .frame(width: 24)

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
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? color.opacity(0.1) : .clear)
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

struct WindowRow: View {
    let window: WindowInfo
    let isSelected: Bool
    let tag: WindowTag?
    let isHovered: Bool
    let onSelect: () -> Void
    let onTag: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Tag color or empty circle
            Circle()
                .fill(tag?.tagColor.color ?? .clear)
                .stroke(tag == nil ? Color.secondary.opacity(0.3) : .clear, lineWidth: 1)
                .frame(width: 10, height: 10)
                .shadow(color: (tag?.tagColor.color ?? .clear).opacity(0.5), radius: 3)

            // Window info
            VStack(alignment: .leading, spacing: 1) {
                Text(tag?.projectName ?? window.ownerName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                if tag != nil {
                    Text(window.ownerName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)

            Spacer()

            // Actions
            if isHovered {
                HStack(spacing: 4) {
                    // Tag button
                    Button(action: onTag) {
                        Image(systemName: tag == nil ? "tag" : "tag.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(tag?.tagColor.color ?? .secondary)
                    }
                    .buttonStyle(.plain)

                    // Select button
                    Button(action: onSelect) {
                        Image(systemName: "scope")
                            .font(.system(size: 10))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            } else if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : (isHovered ? Color.primary.opacity(0.05) : .clear))
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let action: () -> Void

    @State private var isHovered = false

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
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? iconColor.opacity(0.1) : .clear)
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

//
//  PermissionsView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/23/25.
//

import SwiftUI

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
                    Text("✅ All Set!")
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
