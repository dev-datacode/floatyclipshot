//
//  GroupPairingManager.swift
//  floatyclipshot
//
//  Simple group-based pairing: windows with the same group name are paired.
//  One window per group is marked as "primary" (paste destination).
//

import Foundation
import SwiftUI
import Combine

// MARK: - Window Group Assignment

struct WindowGroupAssignment: Codable, Identifiable, Equatable {
    var id: String { "\(ownerName)-\(windowNamePattern)" }

    let ownerName: String           // App name (e.g., "Terminal", "Simulator")
    let windowNamePattern: String   // Window name pattern for matching
    var groupId: String             // Group identifier (e.g., "1", "myproject")
    var isPrimary: Bool             // Is this the paste destination?
    var createdAt: Date

    init(ownerName: String, windowNamePattern: String, groupId: String, isPrimary: Bool = false) {
        self.ownerName = ownerName
        self.windowNamePattern = windowNamePattern
        self.groupId = groupId
        self.isPrimary = isPrimary
        self.createdAt = Date()
    }

    // Match against a WindowInfo
    func matches(_ window: WindowInfo) -> Bool {
        guard window.ownerName == ownerName else { return false }

        // Exact match or pattern match
        if windowNamePattern.isEmpty { return true }
        if window.name == windowNamePattern { return true }
        if window.name.contains(windowNamePattern) { return true }

        return false
    }
}

// MARK: - Active Group (computed from assignments + live windows)

struct ActiveGroup: Identifiable {
    let id: String  // groupId
    let groupId: String
    var members: [GroupMember]

    var primaryMember: GroupMember? {
        members.first { $0.isPrimary }
    }

    var captureTargets: [GroupMember] {
        members.filter { !$0.isPrimary }
    }

    var isValid: Bool {
        primaryMember != nil && !captureTargets.isEmpty
    }
}

struct GroupMember: Identifiable {
    var id: Int { windowId }
    let windowId: Int
    let ownerName: String
    let windowName: String
    let isPrimary: Bool

    var displayName: String {
        if windowName.isEmpty {
            return ownerName
        }
        let truncated = windowName.count > 30 ? String(windowName.prefix(30)) + "..." : windowName
        return "\(ownerName) - \(truncated)"
    }
}

// MARK: - Group Pairing Manager

@MainActor
class GroupPairingManager: ObservableObject {
    static let shared = GroupPairingManager()

    @Published var assignments: [WindowGroupAssignment] = []
    @Published var isEnabled: Bool = true

    private let saveKey = "GroupPairingAssignments"
    private let enabledKey = "GroupPairingEnabled"
    private var saveDebouncer: Timer?

    private init() {
        load()
    }

    // MARK: - Group Management

    /// Set or update the group for a window
    func setGroup(for window: WindowInfo, groupId: String) {
        let pattern = windowPattern(for: window)

        // Remove existing assignment for this window
        assignments.removeAll { $0.ownerName == window.ownerName && $0.windowNamePattern == pattern }

        // Add new assignment if groupId is not empty
        if !groupId.trimmingCharacters(in: .whitespaces).isEmpty {
            let trimmedGroup = groupId.trimmingCharacters(in: .whitespaces)

            // Check if this should be primary (first in group or only member)
            let existingInGroup = assignments.filter { $0.groupId == trimmedGroup }
            let shouldBePrimary = existingInGroup.isEmpty || !existingInGroup.contains { $0.isPrimary }

            let assignment = WindowGroupAssignment(
                ownerName: window.ownerName,
                windowNamePattern: pattern,
                groupId: trimmedGroup,
                isPrimary: shouldBePrimary
            )
            assignments.append(assignment)
        }

        scheduleSave()
    }

    /// Set a window as the primary in its group
    func setPrimary(for window: WindowInfo) {
        let pattern = windowPattern(for: window)

        guard let index = assignments.firstIndex(where: {
            $0.ownerName == window.ownerName && $0.windowNamePattern == pattern
        }) else { return }

        let groupId = assignments[index].groupId

        // Demote all others in the same group
        for i in assignments.indices {
            if assignments[i].groupId == groupId {
                assignments[i].isPrimary = false
            }
        }

        // Promote this one
        assignments[index].isPrimary = true

        scheduleSave()
    }

    /// Remove group assignment for a window
    func removeGroup(for window: WindowInfo) {
        let pattern = windowPattern(for: window)
        assignments.removeAll { $0.ownerName == window.ownerName && $0.windowNamePattern == pattern }
        scheduleSave()
    }

    /// Clear all assignments
    func clearAll() {
        assignments.removeAll()
        scheduleSave()
    }

    // MARK: - Queries

    /// Get the group ID for a window
    func getGroupId(for window: WindowInfo) -> String? {
        findAssignment(for: window)?.groupId
    }

    /// Check if a window is primary in its group
    func isPrimary(for window: WindowInfo) -> Bool {
        findAssignment(for: window)?.isPrimary ?? false
    }

    /// Get assignment for a window
    func findAssignment(for window: WindowInfo) -> WindowGroupAssignment? {
        assignments.first { $0.matches(window) }
    }

    /// Get all unique group IDs
    var allGroupIds: [String] {
        Array(Set(assignments.map { $0.groupId })).sorted()
    }

    /// Get active groups with their members (matched against live windows)
    func getActiveGroups(windows: [WindowInfo]) -> [ActiveGroup] {
        var groups: [String: [GroupMember]] = [:]

        for window in windows {
            if let assignment = findAssignment(for: window) {
                let member = GroupMember(
                    windowId: window.id,
                    ownerName: window.ownerName,
                    windowName: window.name,
                    isPrimary: assignment.isPrimary
                )

                if groups[assignment.groupId] == nil {
                    groups[assignment.groupId] = []
                }
                groups[assignment.groupId]?.append(member)
            }
        }

        return groups.map { groupId, members in
            ActiveGroup(id: groupId, groupId: groupId, members: members)
        }.sorted { $0.groupId < $1.groupId }
    }

    /// Get capture targets for a primary window
    func getCaptureTargets(forPrimary window: WindowInfo, allWindows: [WindowInfo]) -> [WindowInfo] {
        guard let assignment = findAssignment(for: window),
              assignment.isPrimary else { return [] }

        return allWindows.filter { candidateWindow in
            guard candidateWindow.id != window.id else { return false }
            guard let candidateAssignment = findAssignment(for: candidateWindow) else { return false }
            return candidateAssignment.groupId == assignment.groupId && !candidateAssignment.isPrimary
        }
    }

    /// Find the primary window for a group
    func getPrimaryWindow(forGroup groupId: String, allWindows: [WindowInfo]) -> WindowInfo? {
        let primaryAssignment = assignments.first { $0.groupId == groupId && $0.isPrimary }
        guard let primary = primaryAssignment else { return nil }
        return allWindows.first { primary.matches($0) }
    }

    /// Check if a window belongs to any valid group (has both primary and targets)
    func hasValidGroup(for window: WindowInfo, allWindows: [WindowInfo]) -> Bool {
        guard let assignment = findAssignment(for: window) else { return false }

        let groupMembers = allWindows.filter { w in
            if let a = findAssignment(for: w) {
                return a.groupId == assignment.groupId
            }
            return false
        }

        let hasPrimary = groupMembers.contains { isPrimary(for: $0) }
        let hasTargets = groupMembers.contains { !isPrimary(for: $0) }

        return hasPrimary && hasTargets
    }

    // MARK: - Pattern Matching

    /// Generate a matching pattern for a window
    private func windowPattern(for window: WindowInfo) -> String {
        // For terminals, use a simpler pattern (they change titles frequently)
        if TerminalApps.isTerminal(window.ownerName) {
            // Use the working directory part if present
            if let lastComponent = window.name.split(separator: "/").last {
                return String(lastComponent)
            }
            return ""  // Match any window from this terminal app
        }

        // For simulators, use the device name
        if window.ownerName == "Simulator" {
            // Extract device name: "iPhone 15 Pro - iOS 17.0" -> "iPhone 15 Pro"
            if let dashIndex = window.name.firstIndex(of: "-") {
                return String(window.name[..<dashIndex]).trimmingCharacters(in: .whitespaces)
            }
            return window.name
        }

        // For other apps, use the full window name
        return window.name
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveDebouncer?.invalidate()
        saveDebouncer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.save()
            }
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(assignments)
            UserDefaults.standard.set(data, forKey: saveKey)
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        } catch {
            print("Failed to save group assignments: \(error)")
        }
    }

    func load() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        if !UserDefaults.standard.contains(key: enabledKey) {
            isEnabled = true  // Default to enabled
        }

        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }

        do {
            assignments = try JSONDecoder().decode([WindowGroupAssignment].self, from: data)
        } catch {
            print("Failed to load group assignments: \(error)")
            assignments = []
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
