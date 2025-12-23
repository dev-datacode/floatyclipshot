//
//  PairingManager.swift
//  floatyclipshot
//
//  Manages universal window-to-window pairings
//  Supports any window pairing: Terminal→Simulator, Claude→Browser, Slack→App, etc.
//

import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
class PairingManager: ObservableObject {
    static let shared = PairingManager()

    @Published var pairings: [WindowPairing] = []
    @Published var legacyPairings: [TerminalPairing] = []  // For migration
    @Published var isEnabled: Bool = true

    // File management
    private let pairingsFileName = "window_pairings.json"
    private let legacyPairingsFileName = "terminal_pairings.json"

    private var pairingsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? 
                         FileManager.default.homeDirectoryForCurrentUser
        let appFolder = appSupport.appendingPathComponent("FloatyClipshot")
        return appFolder.appendingPathComponent(pairingsFileName)
    }

    private var legacyPairingsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? 
                         FileManager.default.homeDirectoryForCurrentUser
        let appFolder = appSupport.appendingPathComponent("FloatyClipshot")
        return appFolder.appendingPathComponent(legacyPairingsFileName)
    }

    private let saveDebounceInterval: TimeInterval = 0.5
    private var saveTimer: Timer?

    private init() {
        loadPairings()
    }

    // MARK: - Pairing Management

    func addPairing(_ pairing: WindowPairing) {
        // Remove any existing pairing for the same source pattern
        pairings.removeAll { $0.sourceKey == pairing.sourceKey }
        pairings.append(pairing)
        scheduleSave()
        print("🔗 Added pairing: \(pairing.displayName)")
    }

    func updatePairing(_ pairing: WindowPairing) {
        if let index = pairings.firstIndex(where: { $0.id == pairing.id }) {
            pairings[index] = pairing
            scheduleSave()
            print("🔗 Updated pairing: \(pairing.displayName)")
        }
    }

    func deletePairing(_ pairing: WindowPairing) {
        pairings.removeAll { $0.id == pairing.id }
        scheduleSave()
        print("🗑️ Deleted pairing: \(pairing.displayName)")
    }

    func deletePairing(at offsets: IndexSet) {
        pairings.remove(atOffsets: offsets)
        scheduleSave()
    }

    /// Record usage of a pairing (for analytics and sorting)
    func recordUsage(_ pairing: WindowPairing) {
        if let index = pairings.firstIndex(where: { $0.id == pairing.id }) {
            pairings[index].recordUsage()
            scheduleSave()
        }
    }

    // MARK: - Universal Pairing Lookup

    /// Get the pairing that matches a given source window (if any)
    /// Works for ANY app - terminals, IDEs, Claude, Slack, browsers, etc.
    func pairingForSource(_ window: WindowInfo) -> WindowPairing? {
        // Find the most specific match (prefer non-empty patterns over empty ones)
        let matches = pairings.filter { $0.matchesSource(window) }

        // Sort by specificity: non-empty patterns first, then by use count
        let sorted = matches.sorted { (a, b) in
            if !a.sourceTitlePattern.isEmpty && b.sourceTitlePattern.isEmpty {
                return true
            }
            if a.sourceTitlePattern.isEmpty && !b.sourceTitlePattern.isEmpty {
                return false
            }
            // Prefer longer patterns (more specific)
            if a.sourceTitlePattern.count != b.sourceTitlePattern.count {
                return a.sourceTitlePattern.count > b.sourceTitlePattern.count
            }
            // Finally prefer more used pairings
            return a.useCount > b.useCount
        }

        return sorted.first
    }

    /// Find the capture target window for a given source window
    /// Returns the paired target window if one exists and can be found
    func findCaptureTargetForSource(_ sourceWindow: WindowInfo) -> WindowInfo? {
        guard isEnabled else { return nil }

        guard let pairing = pairingForSource(sourceWindow) else {
            return nil
        }

        return findCaptureTarget(for: pairing)
    }

    /// Find the capture target for a specific pairing
    func findCaptureTarget(for pairing: WindowPairing) -> WindowInfo? {
        // Get current window list
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Build WindowInfo array
        var availableWindows: [WindowInfo] = []
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

            let windowInfo = WindowInfo(
                id: windowID,
                name: windowName,
                ownerName: ownerName,
                ownerPID: ownerPID,
                bounds: CGRect(x: x, y: y, width: width, height: height)
            )
            availableWindows.append(windowInfo)
        }

        return pairing.findCaptureTarget(from: availableWindows)
    }

    /// Check if a capture target window is paired to any source
    func hasPairing(forCaptureTarget window: WindowInfo) -> Bool {
        return pairings.contains { pairing in
            guard window.ownerName == pairing.captureOwnerName else { return false }
            if pairing.captureTitlePattern.isEmpty { return true }
            return window.name.localizedCaseInsensitiveContains(pairing.captureTitlePattern)
        }
    }

    /// Get the pairing that targets a specific capture window
    func pairingForCaptureTarget(_ window: WindowInfo) -> WindowPairing? {
        return pairings.first { pairing in
            guard window.ownerName == pairing.captureOwnerName else { return false }
            if pairing.captureTitlePattern.isEmpty { return true }
            return window.name.localizedCaseInsensitiveContains(pairing.captureTitlePattern)
        }
    }

    /// Create a universal pairing from source to capture target
    /// - Parameters:
    ///   - sourceWindow: The window where screenshots will be pasted (any app)
    ///   - captureTarget: The window to capture when triggered from source
    ///   - pasteMode: How to paste (auto-detect, file path, or image)
    /// - Returns: The created pairing (or existing one if duplicate)
    @discardableResult
    func createPairing(
        from sourceWindow: WindowInfo,
        to captureTarget: WindowInfo,
        pasteMode: PasteMode = .auto
    ) -> WindowPairing {
        let sourcePattern = extractPattern(from: sourceWindow.name)
        let capturePattern = extractPattern(from: captureTarget.name)

        // Check for existing pairing with same source and target
        if let existing = pairings.first(where: {
            $0.sourceOwnerName == sourceWindow.ownerName &&
            $0.sourceTitlePattern == sourcePattern &&
            $0.captureOwnerName == captureTarget.ownerName &&
            $0.captureTitlePattern == capturePattern
        }) {
            print("🔗 Pairing already exists: \(existing.displayName)")
            return existing
        }

        // Determine paste mode if auto
        let finalPasteMode: PasteMode
        if pasteMode == .auto {
            // Auto-detect based on source app category
            finalPasteMode = AppRegistry.recommendedPasteMode(for: sourceWindow)
        } else {
            finalPasteMode = pasteMode
        }

        let pairing = WindowPairing(
            sourceOwnerName: sourceWindow.ownerName,
            sourceTitlePattern: sourcePattern,
            captureOwnerName: captureTarget.ownerName,
            captureTitlePattern: capturePattern,
            pasteMode: finalPasteMode
        )
        addPairing(pairing)
        return pairing
    }

    /// Extract a meaningful pattern from a window title
    /// Tries to find a project name or significant identifier
    private func extractPattern(from windowTitle: String) -> String {
        // For terminals, try to extract directory name
        // Common patterns: "user@host:~/project" or "project — Terminal" or "~/project"

        // Split by common delimiters
        let delimiters = CharacterSet(charactersIn: "—-–:|@")
        let parts = windowTitle.components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Look for path-like segments
        for part in parts {
            if part.contains("/") {
                // Extract the last path component
                let pathComponents = part.components(separatedBy: "/")
                if let lastComponent = pathComponents.last, !lastComponent.isEmpty, lastComponent != "~" {
                    return lastComponent
                }
            }
        }

        // Look for the first meaningful part that's not a username or hostname pattern
        for part in parts {
            // Skip if it looks like user@host
            if part.contains("@") { continue }
            // Skip common terminal app names
            if ["Terminal", "iTerm", "bash", "zsh", "sh", "fish"].contains(part) { continue }
            // Skip if too short
            if part.count < 3 { continue }

            return part
        }

        // For non-terminals (simulators, browsers), use the whole title
        // but limit to first 50 chars
        if windowTitle.count > 50 {
            return String(windowTitle.prefix(50))
        }

        return windowTitle
    }

    // MARK: - Legacy Compatibility (TerminalPairing)

    /// Get the pairing that matches a given terminal window (legacy API)
    func pairingForTerminal(_ window: WindowInfo) -> TerminalPairing? {
        // Convert to WindowPairing lookup, then convert back
        if let pairing = pairingForSource(window) {
            return TerminalPairing(
                id: pairing.id,
                terminalOwnerName: pairing.sourceOwnerName,
                terminalTitlePattern: pairing.sourceTitlePattern,
                targetOwnerName: pairing.captureOwnerName,
                targetTitlePattern: pairing.captureTitlePattern
            )
        }
        return nil
    }

    /// Find the target window for a given terminal window (legacy API)
    func findTargetForTerminal(_ terminalWindow: WindowInfo) -> WindowInfo? {
        return findCaptureTargetForSource(terminalWindow)
    }

    /// Create a pairing from terminal to target (legacy API)
    @discardableResult
    func createPairing(from terminalWindow: WindowInfo, to targetWindow: WindowInfo) -> TerminalPairing {
        let windowPairing = createPairing(from: terminalWindow, to: targetWindow, pasteMode: .auto)
        return TerminalPairing(
            id: windowPairing.id,
            terminalOwnerName: windowPairing.sourceOwnerName,
            terminalTitlePattern: windowPairing.sourceTitlePattern,
            targetOwnerName: windowPairing.captureOwnerName,
            targetTitlePattern: windowPairing.captureTitlePattern
        )
    }

    // MARK: - Persistence

    private func loadPairings() {
        // Try loading new format first
        if FileManager.default.fileExists(atPath: pairingsFileURL.path) {
            do {
                let data = try Data(contentsOf: pairingsFileURL)
                pairings = try JSONDecoder().decode([WindowPairing].self, from: data)
                print("✅ Loaded \(pairings.count) window pairings")
                return
            } catch {
                print("⚠️ Failed to load window pairings: \(error)")
            }
        }

        // Fall back to legacy format and migrate
        if FileManager.default.fileExists(atPath: legacyPairingsFileURL.path) {
            do {
                let data = try Data(contentsOf: legacyPairingsFileURL)
                let legacyPairings = try JSONDecoder().decode([TerminalPairing].self, from: data)
                print("📦 Migrating \(legacyPairings.count) legacy terminal pairings...")

                // Convert to new format
                pairings = legacyPairings.map { WindowPairing(from: $0) }
                print("✅ Migrated to \(pairings.count) window pairings")

                // Save in new format
                savePairings()

                // Optionally rename old file as backup
                let backupURL = legacyPairingsFileURL.deletingPathExtension().appendingPathExtension("backup.json")
                try? FileManager.default.moveItem(at: legacyPairingsFileURL, to: backupURL)
                print("💾 Legacy file backed up")

            } catch {
                print("⚠️ Failed to load legacy pairings: \(error)")
            }
        } else {
            print("📁 No pairings file found, starting fresh")
        }
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDebounceInterval, repeats: false) { [weak self] _ in
            self?.savePairings()
        }
    }

    private func savePairings() {
        do {
            // Ensure directory exists
            let directory = pairingsFileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let data = try JSONEncoder().encode(pairings)
            try data.write(to: pairingsFileURL)
            print("💾 Saved \(pairings.count) window pairings")
        } catch {
            print("⚠️ Failed to save pairings: \(error)")
        }
    }

    func savePairingsImmediately() {
        saveTimer?.invalidate()
        savePairings()
    }

    // MARK: - Cleanup

    deinit {
        saveTimer?.invalidate()
    }
}
