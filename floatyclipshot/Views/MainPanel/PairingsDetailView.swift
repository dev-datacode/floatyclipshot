//
//  PairingsDetailView.swift
//  floatyclipshot
//
//  Visual pairing UI - connect windows with one click.
//

import SwiftUI
import AppKit

struct PairingsDetailView: View {
    @ObservedObject private var groupManager = GroupPairingManager.shared
    @ObservedObject private var windowManager = WindowManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @State private var draggedWindow: WindowInfo?
    @State private var dropTargetWindow: WindowInfo?

    // Categorize windows
    private var allWindows: [WindowInfo] {
        windowManager.availableWindows.filter {
            !$0.ownerName.contains("floatyclipshot") && !$0.ownerName.contains("FloatingScreenshot")
        }
    }

    // Windows where you work (terminals, IDEs, chat apps)
    private var sourceWindows: [WindowInfo] {
        allWindows.filter { window in
            let category = AppRegistry.category(forAppName: window.ownerName)
            return category == .terminal || category == .ide || category == .aiChat ||
                   category == .messaging || category == .textEditor
        }
    }

    // Windows you want to capture (simulators, browsers, preview)
    private var targetWindows: [WindowInfo] {
        allWindows.filter { window in
            let name = window.ownerName
            return name == "Simulator" || name == "Safari" || name == "Google Chrome" ||
                   name == "Firefox" || name == "Arc" || name == "Preview" ||
                   name == "Microsoft Edge" || name == "Brave Browser"
        }
    }

    // Get active pairings
    private var activePairings: [VisualPairing] {
        var pairings: [VisualPairing] = []
        let activeGroups = groupManager.getActiveGroups(windows: allWindows)

        for group in activeGroups where group.isValid {
            if let primary = group.primaryMember {
                for target in group.captureTargets {
                    let sourceWindow = allWindows.first { $0.id == primary.windowId }
                    let targetWindow = allWindows.first { $0.id == target.windowId }
                    if let source = sourceWindow, let target = targetWindow {
                        pairings.append(VisualPairing(
                            id: "\(source.id)-\(target.id)",
                            groupId: group.groupId,
                            sourceWindow: source,
                            targetWindow: target
                        ))
                    }
                }
            }
        }
        return pairings
    }

    // Previous app (for context)
    private var previousApp: String {
        windowManager.getPreviousFrontmostApp()?.localizedName ?? "Unknown"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Active Pairings
                if !activePairings.isEmpty {
                    activePairingsSection
                }

                // Quick Pair Section
                quickPairSection

                // All Windows (collapsible)
                allWindowsSection
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            windowManager.forceRefreshWindowList()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Link Windows")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Connect your editor to what you want to capture")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { windowManager.forceRefreshWindowList() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Refresh window list")
            }

            // Hotkey hint
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                Text("Press")
                    .foregroundStyle(.secondary)
                Text(hotkeyManager.pasteHotkeyDisplayString)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("to capture & paste")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }

    // MARK: - Active Pairings

    private var activePairingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Active Links", systemImage: "link.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Spacer()

                if activePairings.count > 1 {
                    Button("Clear All") {
                        groupManager.clearAll()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            ForEach(activePairings) { pairing in
                PairingCard(pairing: pairing) {
                    // Remove this pairing
                    groupManager.removeGroup(for: pairing.targetWindow)
                }
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Pair

    private var quickPairSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with context
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Quick Link", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    if !sourceWindows.isEmpty {
                        Text("Click a target to link with your editor")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if targetWindows.isEmpty {
                // Empty state
                emptyTargetsView
            } else {
                // Show available targets
                VStack(spacing: 8) {
                    // Source selector (if multiple)
                    if sourceWindows.count > 1 {
                        sourceSelector
                    } else if let source = sourceWindows.first {
                        currentSourceBadge(source)
                    }

                    // Target grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(targetWindows) { target in
                            TargetCard(
                                window: target,
                                isLinked: isLinked(target),
                                onTap: { linkTarget(target) }
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @State private var selectedSourceIndex = 0

    private var sourceSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paste screenshots to:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(sourceWindows.enumerated()), id: \.element.id) { index, source in
                        Button {
                            selectedSourceIndex = index
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: iconFor(source))
                                    .foregroundStyle(colorFor(source))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(displayNameFor(source))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    if !source.name.isEmpty && source.name != source.ownerName {
                                        Text(source.ownerName)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedSourceIndex == index ? colorFor(source).opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedSourceIndex == index ? colorFor(source) : Color.clear, lineWidth: 2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func currentSourceBadge(_ source: WindowInfo) -> some View {
        HStack(spacing: 8) {
            Text("Paste to:")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: iconFor(source))
                    .foregroundStyle(colorFor(source))
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayNameFor(source))
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if !source.name.isEmpty && source.name != source.ownerName {
                        Text(source.ownerName)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(colorFor(source).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
    }

    /// Get a meaningful display name for a window
    /// For terminals, extract the project/directory name from the title
    private func displayNameFor(_ window: WindowInfo) -> String {
        let name = window.name

        // If no window title, use app name
        if name.isEmpty {
            return window.ownerName
        }

        // For terminals, try to extract the meaningful part
        let category = AppRegistry.category(forAppName: window.ownerName)
        if category == .terminal || category == .ide {
            // Common patterns in terminal titles:
            // "username@hostname: ~/projects/myapp"
            // "~/projects/myapp"
            // "myapp — zsh"
            // "zsh - myapp"

            // Try to extract path component
            if let colonIndex = name.lastIndex(of: ":") {
                let afterColon = String(name[name.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if afterColon.hasPrefix("~") || afterColon.hasPrefix("/") {
                    // It's a path, get the last component
                    let pathComponents = afterColon.split(separator: "/")
                    if let lastComponent = pathComponents.last {
                        return String(lastComponent)
                    }
                }
                return afterColon.isEmpty ? window.ownerName : String(afterColon.prefix(25))
            }

            // Try dash separator (e.g., "zsh - myapp")
            if let dashRange = name.range(of: " — ") ?? name.range(of: " - ") {
                let parts = [String(name[..<dashRange.lowerBound]), String(name[dashRange.upperBound...])]
                // Return the part that looks like a project name (not shell name)
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if !["zsh", "bash", "fish", "sh", "Terminal"].contains(trimmed) {
                        return String(trimmed.prefix(25))
                    }
                }
            }

            // Check if it's a path directly
            if name.hasPrefix("~") || name.hasPrefix("/") {
                let pathComponents = name.split(separator: "/")
                if let lastComponent = pathComponents.last {
                    return String(lastComponent)
                }
            }
        }

        // For other apps, use the window title (truncated)
        return String(name.prefix(25)) + (name.count > 25 ? "..." : "")
    }

    private var emptyTargetsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No capture targets found")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Open Simulator, Safari, or Chrome to capture screenshots")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    // MARK: - All Windows

    @State private var showAllWindows = false

    private var allWindowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showAllWindows.toggle()
                }
            } label: {
                HStack {
                    Label("All Windows (\(allWindows.count))", systemImage: "macwindow.on.rectangle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: showAllWindows ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if showAllWindows {
                VStack(spacing: 8) {
                    ForEach(allWindows) { window in
                        CompactWindowRow(window: window)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var selectedSource: WindowInfo? {
        guard selectedSourceIndex < sourceWindows.count else { return sourceWindows.first }
        return sourceWindows[selectedSourceIndex]
    }

    private func isLinked(_ target: WindowInfo) -> Bool {
        groupManager.getGroupId(for: target) != nil
    }

    private func linkTarget(_ target: WindowInfo) {
        guard let source = selectedSource else { return }

        // Create a unique group ID for this pairing
        let groupId = "\(source.ownerName.prefix(3))-\(Int.random(in: 100...999))"

        // Set the source as primary
        groupManager.setGroup(for: source, groupId: groupId)
        groupManager.setPrimary(for: source)

        // Add the target to the same group
        groupManager.setGroup(for: target, groupId: groupId)
    }

    private func iconFor(_ window: WindowInfo) -> String {
        switch window.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome", "Chrome": return "globe"
        case "Firefox": return "flame"
        case "Terminal": return "terminal"
        case "iTerm2", "iTerm": return "terminal.fill"
        case "Xcode": return "hammer"
        case "Code", "Visual Studio Code": return "chevron.left.forwardslash.chevron.right"
        case "Cursor": return "cursorarrow.rays"
        case "Preview": return "photo"
        default: return "macwindow"
        }
    }

    private func colorFor(_ window: WindowInfo) -> Color {
        switch window.ownerName {
        case "Simulator": return .blue
        case "Safari": return .blue
        case "Google Chrome", "Chrome": return .yellow
        case "Firefox": return .orange
        case "Terminal", "iTerm2", "iTerm": return .green
        case "Xcode": return .blue
        case "Code", "Visual Studio Code", "Cursor": return .purple
        default: return .gray
        }
    }
}

// MARK: - Visual Pairing Model

struct VisualPairing: Identifiable {
    let id: String
    let groupId: String
    let sourceWindow: WindowInfo
    let targetWindow: WindowInfo
}

// MARK: - Pairing Card (shows connection)

struct PairingCard: View {
    let pairing: VisualPairing
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Source (paste destination)
            windowBadge(pairing.sourceWindow, role: .source)

            // Arrow connector
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.green.opacity(0.5))
                    .frame(height: 2)

                Image(systemName: "arrow.left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)

                Rectangle()
                    .fill(Color.green.opacity(0.5))
                    .frame(height: 2)
            }
            .frame(width: 60)

            // Target (capture source)
            windowBadge(pairing.targetWindow, role: .target)

            Spacer()

            // Remove button
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    enum WindowRole { case source, target }

    private func windowBadge(_ window: WindowInfo, role: WindowRole) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconFor(window))
                .font(.system(size: 16))
                .foregroundStyle(role == .source ? .green : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayNameFor(window))
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(window.ownerName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(role == .source ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Get a meaningful display name for a window
    private func displayNameFor(_ window: WindowInfo) -> String {
        let name = window.name

        if name.isEmpty {
            return window.ownerName
        }

        // For terminals/IDEs, extract project name
        let category = AppRegistry.category(forAppName: window.ownerName)
        if category == .terminal || category == .ide {
            // Pattern: "user@host: ~/path/to/project"
            if let colonIndex = name.lastIndex(of: ":") {
                let afterColon = String(name[name.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                if afterColon.hasPrefix("~") || afterColon.hasPrefix("/") {
                    let pathComponents = afterColon.split(separator: "/")
                    if let lastComponent = pathComponents.last {
                        return String(lastComponent)
                    }
                }
                return afterColon.isEmpty ? window.ownerName : String(afterColon.prefix(20))
            }

            // Pattern: "project — zsh" or "zsh - project"
            if let dashRange = name.range(of: " — ") ?? name.range(of: " - ") {
                let parts = [String(name[..<dashRange.lowerBound]), String(name[dashRange.upperBound...])]
                for part in parts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if !["zsh", "bash", "fish", "sh", "Terminal"].contains(trimmed) {
                        return String(trimmed.prefix(20))
                    }
                }
            }

            // Direct path
            if name.hasPrefix("~") || name.hasPrefix("/") {
                let pathComponents = name.split(separator: "/")
                if let lastComponent = pathComponents.last {
                    return String(lastComponent)
                }
            }
        }

        // For simulators, show device name
        if window.ownerName == "Simulator" {
            if let dashIndex = name.firstIndex(of: "-") {
                return String(name[..<dashIndex]).trimmingCharacters(in: .whitespaces)
            }
        }

        return String(name.prefix(20)) + (name.count > 20 ? "..." : "")
    }

    private func iconFor(_ window: WindowInfo) -> String {
        switch window.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Terminal": return "terminal"
        case "iTerm2": return "terminal.fill"
        case "Code", "Visual Studio Code": return "chevron.left.forwardslash.chevron.right"
        case "Cursor": return "cursorarrow.rays"
        default: return "macwindow"
        }
    }
}

// MARK: - Target Card (clickable capture target)

struct TargetCard: View {
    let window: WindowInfo
    let isLinked: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colorFor(window).opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: iconFor(window))
                        .font(.system(size: 22))
                        .foregroundStyle(colorFor(window))

                    // Link indicator
                    if isLinked {
                        Circle()
                            .fill(.green)
                            .frame(width: 14, height: 14)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .offset(x: 16, y: 16)
                    }
                }

                // Name
                VStack(spacing: 2) {
                    Text(displayNameFor(window))
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(window.ownerName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isLinked ? Color.green.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isLinked ? Color.green.opacity(0.5) : (isHovered ? Color.blue.opacity(0.5) : Color.clear), lineWidth: 2)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isLinked)
    }

    /// Get a meaningful display name for capture targets
    private func displayNameFor(_ window: WindowInfo) -> String {
        let name = window.name

        if name.isEmpty {
            return window.ownerName
        }

        // For simulators, show device name
        if window.ownerName == "Simulator" {
            // "iPhone 15 Pro - iOS 17.0" -> "iPhone 15 Pro"
            if let dashIndex = name.firstIndex(of: "-") {
                return String(name[..<dashIndex]).trimmingCharacters(in: .whitespaces)
            }
            return name
        }

        // For browsers, show page title
        if ["Safari", "Google Chrome", "Firefox", "Arc", "Microsoft Edge", "Brave Browser"].contains(window.ownerName) {
            // Truncate long page titles
            return String(name.prefix(18)) + (name.count > 18 ? "..." : "")
        }

        return String(name.prefix(18)) + (name.count > 18 ? "..." : "")
    }

    private func iconFor(_ window: WindowInfo) -> String {
        switch window.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Firefox": return "flame"
        case "Preview": return "photo"
        default: return "macwindow"
        }
    }

    private func colorFor(_ window: WindowInfo) -> Color {
        switch window.ownerName {
        case "Simulator": return .blue
        case "Safari": return .blue
        case "Google Chrome": return .yellow
        case "Firefox": return .orange
        case "Preview": return .pink
        default: return .gray
        }
    }
}

// MARK: - Compact Window Row

struct CompactWindowRow: View {
    let window: WindowInfo
    @ObservedObject private var groupManager = GroupPairingManager.shared
    @State private var groupText: String = ""

    private var hasGroup: Bool {
        !groupText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isPrimary: Bool {
        groupManager.isPrimary(for: window)
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: iconFor(window))
                .font(.system(size: 14))
                .foregroundStyle(colorFor(window))
                .frame(width: 20)

            // Info
            VStack(alignment: .leading, spacing: 1) {
                Text(window.ownerName)
                    .font(.caption)
                    .fontWeight(.medium)
                if !window.name.isEmpty {
                    Text(window.name)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Group badge
            if hasGroup {
                HStack(spacing: 4) {
                    Text(groupText)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    if isPrimary {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isPrimary ? Color.green : Color.orange)
                .clipShape(Capsule())
            }

            // Quick group input
            TextField("group", text: $groupText)
                .textFieldStyle(.plain)
                .font(.system(size: 10))
                .frame(width: 50)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onSubmit {
                    groupManager.setGroup(for: window, groupId: groupText)
                }

            // Primary toggle
            if hasGroup {
                Button {
                    groupManager.setPrimary(for: window)
                } label: {
                    Image(systemName: isPrimary ? "arrow.right.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(isPrimary ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help(isPrimary ? "Primary (paste here)" : "Make primary")
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            groupText = groupManager.getGroupId(for: window) ?? ""
        }
    }

    private func iconFor(_ window: WindowInfo) -> String {
        switch window.ownerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Terminal": return "terminal"
        case "iTerm2": return "terminal.fill"
        case "Xcode": return "hammer"
        case "Code", "Visual Studio Code": return "chevron.left.forwardslash.chevron.right"
        case "Cursor": return "cursorarrow.rays"
        default: return "macwindow"
        }
    }

    private func colorFor(_ window: WindowInfo) -> Color {
        switch window.ownerName {
        case "Simulator": return .blue
        case "Safari": return .blue
        case "Google Chrome": return .yellow
        case "Terminal", "iTerm2": return .green
        case "Xcode": return .blue
        case "Code", "Visual Studio Code", "Cursor": return .purple
        default: return .gray
        }
    }
}

#Preview {
    PairingsDetailView()
        .frame(width: 500, height: 600)
}
