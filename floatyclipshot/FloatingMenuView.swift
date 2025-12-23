//
//  FloatingMenuView.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Creative floating menu with tabs for windows, clipboard, and settings
//

import SwiftUI
import AppKit

// MARK: - Floating Menu Controller

/// Manages the floating menu window for quick access
final class FloatingMenuController {
    static let shared = FloatingMenuController()

    private var window: NSWindow?
    private var monitor: Any?

    private init() {}

    /// Show the floating menu near the floating button
    func show(near buttonFrame: CGRect? = nil) {
        // If window exists and is visible, just bring it to front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Remove old monitor if exists
        if let oldMonitor = monitor {
            NSEvent.removeMonitor(oldMonitor)
            monitor = nil
        }

        // Create the SwiftUI content
        let contentView = StandaloneFloatingMenuView()

        // Create hosting controller
        let hostingController = NSHostingController(rootView: contentView)

        // Create borderless window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.contentViewController = hostingController
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = true
        newWindow.level = .floating
        newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        newWindow.isMovableByWindowBackground = true

        // Position near button or center
        if let frame = buttonFrame {
            // Position to the left of the button
            let x = frame.minX - 330
            let y = frame.midY - 210
            newWindow.setFrameOrigin(NSPoint(x: max(10, x), y: max(10, y)))
        } else {
            newWindow.center()
        }

        // Store reference and show
        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Close when clicking outside
        setupClickOutsideHandler()
    }

    /// Close the floating menu
    func close() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        
        // Use orderOut instead of close for a "softer" removal that prevents
        // SwiftUI deallocation race conditions
        window?.orderOut(nil)
        window = nil
    }

    /// Toggle visibility
    func toggle(near buttonFrame: CGRect? = nil) {
        if let existingWindow = window, existingWindow.isVisible {
            close()
        } else {
            show(near: buttonFrame)
        }
    }

    /// Check if visible
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    private func setupClickOutsideHandler() {
        // Close on click outside
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            let windowFrame = window.frame
            let screenClick = NSEvent.mouseLocation

            if !windowFrame.contains(screenClick) {
                self.close()
            }
        }
    }
}

// MARK: - Standalone Floating Menu View

/// Standalone version that manages its own state and uses window controllers for child views
struct StandaloneFloatingMenuView: View {
    @State private var showTagEditor = false
    @State private var showTagList = false
    @State private var showHotkeyRecorder = false
    @State private var showPasteHotkeyRecorder = false
    @State private var showStorageSettings = false
    @State private var showQuickNote = false
    @State private var showNotesList = false
    @State private var showPermissionsView = false
    @State private var windowToTag: WindowInfo?

    private var missingPermissions: Bool {
        !ScreenshotManager.shared.isScreenRecordingGranted() || !ScreenshotManager.shared.isAccessibilityGranted()
    }

    // Dummy binding that closes the controller
    private var showFloatingMenuBinding: Binding<Bool> {
        Binding(
            get: { FloatingMenuController.shared.isVisible },
            set: { newValue in
                if !newValue {
                    FloatingMenuController.shared.close()
                }
            }
        )
    }

    var body: some View {
        FloatingMenuView(
            showFloatingMenu: showFloatingMenuBinding,
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
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

    // Feedback toast
    @State private var toastMessage: String = ""
    @State private var toastType: ToastType = .success
    @State private var showToast: Bool = false

    enum ToastType {
        case success, error, info
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .orange
            }
        }
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    // Local copies to avoid crashes from ObservedObject updates during view lifecycle
    @State private var cachedWindows: [WindowInfo] = []
    @State private var cachedClipboardItems: [ClipboardItem] = []
    @State private var cachedIsPaused: Bool = false
    @State private var cachedHotkeyEnabled: Bool = false
    @State private var cachedHotkeyString: String = ""
    @State private var cachedSelectedWindow: WindowInfo?
    @State private var cachedPreviousFrontmostApp: String = ""

    private let tabs = ["Windows", "Clipboard", "Settings"]
    private let tabIcons = ["macwindow.on.rectangle", "doc.on.clipboard", "gearshape"]

    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    // Note: No animation on tab switch to prevent popover resize crash on macOS 26
                    Button(action: { selectedTab = index }) {
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
                                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))

            GlassDivider(opacity: GlassDesign.Opacity.subtle)

            // Content - Fixed height to prevent popover resize crashes on macOS 26
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
                .frame(minHeight: 260, alignment: .top) // Ensure minimum content height
            }
            .frame(height: 280)
            .clipped() // Prevent content overflow during transitions

            GlassDivider(opacity: GlassDesign.Opacity.subtle)

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
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        }
        .onAppear {
            refreshCache()
        }
        .overlay(alignment: .top) {
            // Toast notification
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: toastType.icon)
                        .foregroundStyle(toastType.color)
                    Text(toastMessage)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .transition(.glassSlideDown)
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.3), value: showToast)
    }

    private func showToast(_ message: String, type: ToastType = .success) {
        toastMessage = message
        toastType = type
        withAnimation {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showToast = false
            }
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
        cachedPreviousFrontmostApp = WindowManager.shared.getPreviousFrontmostApp()?.localizedName ?? ""
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
        // Quick Pair Section - Show when menu opened from a terminal
        if TerminalApps.isTerminal(cachedPreviousFrontmostApp) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.orange)
                    Text("Quick Pair from \(cachedPreviousFrontmostApp)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 4)

                // Show simulators/targets for quick pairing
                let targets = ScreenshotManager.shared.getOnScreenTargets()
                if targets.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("No simulators or browsers on this Space")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(targets) { target in
                        QuickPairRow(
                            target: target,
                            existingPairing: PairingManager.shared.pairingForCaptureTarget(target),
                            onPair: {
                                if let sourceWindow = ScreenshotManager.shared.getActiveSourceWindow() {
                                    PairingManager.shared.createPairing(from: sourceWindow, to: target, pasteMode: .auto)
                                    showToast("Paired: \(sourceWindow.ownerName) → \(target.ownerName)", type: .success)
                                    refreshCache()
                                }
                            },
                            onUnpair: {
                                if let existing = PairingManager.shared.pairingForCaptureTarget(target) {
                                    PairingManager.shared.deletePairing(existing)
                                    showToast("Pairing removed", type: .info)
                                    refreshCache()
                                }
                            },
                            onCapture: {
                                showFloatingMenu = false
                                ScreenshotManager.shared.captureWithTarget(target, andCreatePairing: true)
                            }
                        )
                    }
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.orange.opacity(0.1))
            }
        }

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
        LazyVStack(spacing: 4) {
            ForEach(cachedWindows) { window in
                WindowRow(
                    window: window,
                    isSelected: cachedSelectedWindow?.id == window.id,
                    tag: TagManager.shared.tagForWindow(window),
                    pairing: PairingManager.shared.pairingForCaptureTarget(window),
                    isHovered: hoveredWindow == window.id,
                    previousFrontmostApp: cachedPreviousFrontmostApp,
                    onSelect: {
                        WindowManager.shared.selectWindow(window)
                        // Small delay to ensure state update completes before window closure
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showFloatingMenu = false
                        }
                    },
                    onTag: {
                        windowToTag = window
                        showFloatingMenu = false
                        // Longer delay to ensure popover fully closes before sheet opens
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showTagEditor = true
                        }
                    },
                    onPair: {
                        // Create pairing from the previous frontmost terminal to this window
                        if let terminalWindow = ScreenshotManager.shared.getActiveTerminalWindow() {
                            let pairing = PairingManager.shared.createPairing(from: terminalWindow, to: window)
                            showToast("Paired: \(pairing.terminalDisplayName) → \(pairing.targetDisplayName)", type: .success)
                            refreshCache()  // Refresh to show updated pairing state
                        } else {
                            showToast("Open menu from a terminal to create pairing", type: .error)
                        }
                    },
                    onUnpair: {
                        // Remove the pairing for this target window
                        if let existingPairing = PairingManager.shared.pairingForCaptureTarget(window) {
                            PairingManager.shared.deletePairing(existingPairing)
                            showToast("Pairing removed", type: .info)
                            refreshCache()  // Refresh to show updated pairing state
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showHotkeyRecorder = true
            }
        }

        // Storage
        MenuButton(icon: "externaldrive.fill", title: "Storage Settings", color: .gray) {
            showFloatingMenu = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showStorageSettings = true
            }
        }

        GlassDivider()

        // Terminal Pairings
        MenuButton(icon: "link.circle.fill", title: "Manage Pairings", color: .orange) {
            showFloatingMenu = false
            // Open Main Panel directly to the Pairings tab
            // This prevents issues with sheets closing when the floating menu closes
            MainPanelController.shared.show(tab: .pairings)
        }

        Spacer()

        // Quit
        MenuButton(icon: "power", title: "Quit", color: .red) {
            NSApplication.shared.terminate(nil)
        }
    }
}
