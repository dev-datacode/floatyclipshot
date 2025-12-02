//
//  TagManager.swift
//  floatyclipshot
//
//  Manages window tags and their floating overlay displays
//

import Foundation
import SwiftUI
import AppKit
import Combine

class TagManager: ObservableObject {
    static let shared = TagManager()

    @Published var tags: [WindowTag] = []
    @Published var isEnabled: Bool = true

    // Track active overlay windows by window ID
    private var overlayWindows: [Int: NSWindow] = [:]
    private var windowUpdateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // File management
    private let tagsFileName = "window_tags.json"
    private var tagsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("FloatyClipshot")
        return appFolder.appendingPathComponent(tagsFileName)
    }

    private let saveDebounceInterval: TimeInterval = 0.5
    private var saveTimer: Timer?

    private init() {
        loadTags()
        setupWindowMonitoring()
        setupWorkspaceNotifications()
    }

    // MARK: - Tag Management

    func addTag(_ tag: WindowTag) {
        tags.append(tag)
        scheduleSave()
        refreshOverlays()
    }

    func updateTag(_ tag: WindowTag) {
        if let index = tags.firstIndex(where: { $0.id == tag.id }) {
            tags[index] = tag
            scheduleSave()
            refreshOverlays()
        }
    }

    func deleteTag(_ tag: WindowTag) {
        tags.removeAll { $0.id == tag.id }
        scheduleSave()
        refreshOverlays()
    }

    func deleteTag(at offsets: IndexSet) {
        tags.remove(atOffsets: offsets)
        scheduleSave()
        refreshOverlays()
    }

    /// Get the tag that matches a given window (if any)
    func tagForWindow(_ window: WindowInfo) -> WindowTag? {
        return tags.first { $0.matches(window: window) }
    }

    /// Check if a window has a tag
    func hasTag(for window: WindowInfo) -> Bool {
        return tagForWindow(window) != nil
    }

    /// Create a tag from the currently selected window
    func createTagForWindow(_ window: WindowInfo, projectName: String, color: TagColor, position: TagPosition = .topLeft) -> WindowTag {
        let tag = WindowTag(
            projectName: projectName,
            tagColor: color,
            ownerName: window.ownerName,
            windowNamePattern: window.name,
            showProjectName: true,
            position: position
        )
        addTag(tag)
        return tag
    }

    // MARK: - Window Monitoring

    private func setupWindowMonitoring() {
        // Timer for position updates only (windows moving/resizing)
        // Reduced frequency since we use notifications for window changes
        windowUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateOverlayPositions()
        }

        // Monitor for enabled state changes
        $isEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled {
                    self?.refreshOverlays()
                } else {
                    self?.hideAllOverlays()
                }
            }
            .store(in: &cancellables)
    }

    private func setupWorkspaceNotifications() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        // App launched - new windows may appear
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAppEvent),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        // App terminated - windows will disappear
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAppEvent),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // App activated - window might have changed
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAppEvent),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // App hidden/unhidden
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAppEvent),
            name: NSWorkspace.didHideApplicationNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(handleAppEvent),
            name: NSWorkspace.didUnhideApplicationNotification,
            object: nil
        )

        // Space changed - visible windows change
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAppEvent),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // Screen configuration changed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppEvent),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleAppEvent(_ notification: Notification) {
        // Debounce rapid notifications by scheduling refresh on main queue
        DispatchQueue.main.async { [weak self] in
            self?.refreshOverlays()
        }
    }

    // MARK: - Overlay Management

    func refreshOverlays() {
        guard isEnabled else {
            hideAllOverlays()
            return
        }

        // Get current windows
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var currentWindowIDs = Set<Int>()

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? Int,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            // Skip our own windows
            if ownerName.contains("floatyclipshot") || ownerName.contains("FloatingScreenshot") {
                continue
            }

            let windowName = windowDict[kCGWindowName as String] as? String ?? ""
            let ownerPID = windowDict[kCGWindowOwnerPID as String] as? Int ?? 0
            let x = boundsDict["X"] as? CGFloat ?? 0
            let y = boundsDict["Y"] as? CGFloat ?? 0
            let width = boundsDict["Width"] as? CGFloat ?? 0
            let height = boundsDict["Height"] as? CGFloat ?? 0

            // Skip small windows
            guard width >= 100 && height >= 100 else { continue }

            let windowInfo = WindowInfo(id: windowID, name: windowName, ownerName: ownerName, ownerPID: ownerPID, bounds: CGRect(x: x, y: y, width: width, height: height))

            // Check if this window has a matching tag
            if let tag = tagForWindow(windowInfo) {
                currentWindowIDs.insert(windowID)
                showOrUpdateOverlay(for: windowInfo, tag: tag)
            }
        }

        // Remove overlays for windows that no longer exist or don't have tags
        let staleWindowIDs = Set(overlayWindows.keys).subtracting(currentWindowIDs)
        for windowID in staleWindowIDs {
            if let overlay = overlayWindows.removeValue(forKey: windowID) {
                overlay.orderOut(nil)
            }
        }
    }

    private func showOrUpdateOverlay(for window: WindowInfo, tag: WindowTag) {
        let overlaySize = calculateOverlaySize(for: tag)
        let overlayPosition = calculateOverlayPosition(for: window, tag: tag, overlaySize: overlaySize)

        if let existingOverlay = overlayWindows[window.id] {
            // Update existing overlay position
            existingOverlay.setFrameOrigin(overlayPosition)
        } else {
            // Create new overlay window
            let overlay = createOverlayWindow(for: tag, at: overlayPosition, size: overlaySize)
            overlayWindows[window.id] = overlay
            overlay.orderFront(nil)
        }
    }

    private func createOverlayWindow(for tag: WindowTag, at position: CGPoint, size: CGSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: position, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true  // Click-through
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        let tagView = FloatingTagView(tag: tag)
        let hostingView = NSHostingView(rootView: tagView)
        hostingView.frame = NSRect(origin: .zero, size: size)
        window.contentView = hostingView

        return window
    }

    private func calculateOverlaySize(for tag: WindowTag) -> CGSize {
        // Calculate size based on text length - creative capsule design
        let font = NSFont.systemFont(ofSize: 15, weight: .bold)
        let text = tag.projectName as NSString
        let textSize = text.size(withAttributes: [.font: font])

        // Extra padding for orb + capsule shape
        let width = max(textSize.width + 72, 100)
        let height: CGFloat = 44

        return CGSize(width: width, height: height)
    }

    private func calculateOverlayPosition(for window: WindowInfo, tag: WindowTag, overlaySize: CGSize) -> CGPoint {
        // Convert from CG coordinates (origin at top-left) to NS coordinates (origin at bottom-left)
        guard let screen = NSScreen.main else {
            return .zero
        }

        let screenHeight = screen.frame.height
        let windowFrame = window.bounds

        // Convert window bounds from CG to NS coordinate system
        let nsWindowOriginY = screenHeight - windowFrame.origin.y - windowFrame.height

        let padding: CGFloat = 8

        switch tag.position {
        case .topLeft:
            return CGPoint(
                x: windowFrame.origin.x + padding,
                y: nsWindowOriginY + windowFrame.height - overlaySize.height - padding - 28  // Account for title bar
            )
        case .topRight:
            return CGPoint(
                x: windowFrame.origin.x + windowFrame.width - overlaySize.width - padding,
                y: nsWindowOriginY + windowFrame.height - overlaySize.height - padding - 28
            )
        case .bottomLeft:
            return CGPoint(
                x: windowFrame.origin.x + padding,
                y: nsWindowOriginY + padding
            )
        case .bottomRight:
            return CGPoint(
                x: windowFrame.origin.x + windowFrame.width - overlaySize.width - padding,
                y: nsWindowOriginY + padding
            )
        }
    }

    private func updateOverlayPositions() {
        guard isEnabled else { return }
        refreshOverlays()
    }

    private func hideAllOverlays() {
        for (_, overlay) in overlayWindows {
            overlay.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    // MARK: - Persistence

    private func loadTags() {
        guard FileManager.default.fileExists(atPath: tagsFileURL.path) else {
            print("📁 No tags file found, starting fresh")
            return
        }

        do {
            let data = try Data(contentsOf: tagsFileURL)
            tags = try JSONDecoder().decode([WindowTag].self, from: data)
            print("✅ Loaded \(tags.count) window tags")
        } catch {
            print("⚠️ Failed to load tags: \(error)")
        }
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
            self?.saveTags()
        }
    }

    private func saveTags() {
        do {
            // Ensure directory exists
            let directory = tagsFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let data = try JSONEncoder().encode(tags)
            try data.write(to: tagsFileURL)
            print("💾 Saved \(tags.count) window tags")
        } catch {
            print("⚠️ Failed to save tags: \(error)")
        }
    }

    func saveTagsImmediately() {
        saveTimer?.invalidate()
        saveTags()
    }

    // MARK: - Cleanup

    deinit {
        windowUpdateTimer?.invalidate()
        saveTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        hideAllOverlays()
    }
}

// MARK: - Floating Tag View

struct FloatingTagView: View {
    let tag: WindowTag
    @State private var isHovered = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            // Animated color orb with pulsing glow
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(tag.tagColor.color.opacity(0.3))
                    .frame(width: 22, height: 22)
                    .blur(radius: 4)
                    .scaleEffect(pulse ? 1.3 : 1.0)

                // Inner vibrant orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tag.tagColor.color.opacity(0.9),
                                tag.tagColor.color
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 12
                        )
                    )
                    .frame(width: 16, height: 16)

                // Highlight sparkle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.8),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 6
                        )
                    )
                    .frame(width: 16, height: 16)
                    .offset(x: -3, y: -3)
            }
            .shadow(color: tag.tagColor.color.opacity(0.7), radius: 8, x: 0, y: 2)

            // Project name with gradient text
            if tag.showProjectName {
                Text(tag.projectName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .primary,
                                .primary.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background {
            ZStack {
                // Base glass layer
                Capsule()
                    .fill(.ultraThinMaterial)
                    .glassEffect()

                // Colored tint overlay
                Capsule()
                    .fill(tag.tagColor.color.opacity(0.08))

                // Top highlight
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.25),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.5),
                            tag.tagColor.color.opacity(0.3),
                            .white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        .shadow(color: tag.tagColor.color.opacity(0.3), radius: 16, x: 0, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(TagColor.allCases) { color in
            FloatingTagView(tag: WindowTag(
                projectName: "Project \(color.displayName)",
                tagColor: color,
                ownerName: "Xcode",
                windowNamePattern: ""
            ))
        }
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
