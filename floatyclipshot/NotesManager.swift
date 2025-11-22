//
//  NotesManager.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import Foundation
import SwiftUI
import Combine

/// Simple note with optional key-value structure
struct QuickNote: Identifiable, Codable, Equatable {
    let id: UUID
    var key: String  // Title or key
    var value: String  // Content or value
    let timestamp: Date
    var isPinned: Bool

    init(id: UUID = UUID(), key: String, value: String, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.key = key
        self.value = value
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    var displayText: String {
        if key.isEmpty {
            return value
        }
        return "\(key): \(value)"
    }

    var shortDisplayText: String {
        let display = displayText
        return String(display.prefix(50)) + (display.count > 50 ? "..." : "")
    }
}

class NotesManager: ObservableObject {
    static let shared = NotesManager()

    @Published var notes: [QuickNote] = []
    private let notesFile: URL
    private let ioQueue = DispatchQueue(label: "com.floatyclipshot.notes", qos: .utility)
    private var saveTimer: Timer?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("FloatyClipshot", isDirectory: true)
        notesFile = directory.appendingPathComponent("notes.json")

        // Ensure directory exists and is writable
        createAndVerifyStorageDirectory(directory)

        // Load saved notes
        loadNotes()
    }

    /// Create and verify storage directory is writable
    /// Shows critical alert if directory cannot be created or is read-only
    private func createAndVerifyStorageDirectory(_ directory: URL) {
        let fm = FileManager.default

        do {
            // Create directory
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)

            // CRITICAL: Verify directory is writable by creating a test file
            let testFile = directory.appendingPathComponent(".writetest_\(UUID().uuidString)")
            let testData = Data("test".utf8)

            try testData.write(to: testFile)
            try fm.removeItem(at: testFile)

            print("✅ Notes storage directory verified: \(directory.path)")

        } catch {
            print("🚨 CRITICAL: Notes storage directory unusable: \(error)")

            // Show critical alert - notes cannot be saved
            DispatchQueue.main.async { [weak self] in
                self?.showCriticalAlert(
                    title: "Storage Error",
                    message: """
                    Cannot create or write to notes directory:
                    \(directory.path)

                    Error: \(error.localizedDescription)

                    Possible causes:
                    • Disk is full
                    • Permissions denied
                    • Read-only filesystem

                    The app cannot save your notes.
                    """
                )
            }
        }
    }

    // MARK: - Persistence

    /// Set secure file permissions (owner read/write only)
    private func setSecurePermissions(for fileURL: URL) {
        do {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } catch {
            print("⚠️ Failed to set secure permissions on \(fileURL.lastPathComponent): \(error)")
        }
    }

    /// Check if there's sufficient disk space before saving
    /// Accounts for current file + 5 rotating backups (6x total space)
    private func hasEnoughDiskSpace(requiredBytes: Int64) -> Bool {
        do {
            let directory = notesFile.deletingLastPathComponent()
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: directory.path)
            if let freeSize = attributes[.systemFreeSize] as? Int64 {
                // Account for current file (1x) + 5 backups (5x) = 6x total
                let totalRequired = requiredBytes * 6
                // Use 50% margin OR 100MB minimum, whichever is larger
                let safetyMargin = max(Int64(Double(totalRequired) * 0.5), 100_000_000)
                let totalNeeded = totalRequired + safetyMargin

                if freeSize <= totalNeeded {
                    print("⚠️ Insufficient disk space: need \(formatBytes(totalNeeded)), have \(formatBytes(freeSize))")
                    return false
                }
                return true
            }
        } catch {
            print("⚠️ Failed to check disk space: \(error)")
        }
        // If check fails, be conservative and deny save
        return false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Migrate old single backup to new rotating format
    /// Old: notes.json.backup → New: notes.json.backup.1
    private func migrateOldBackup(for fileURL: URL) {
        let fm = FileManager.default
        let oldBackup = fileURL.appendingPathExtension("backup")
        let newBackup1 = fileURL.appendingPathExtension("backup.1")

        // If old backup exists but new format doesn't, migrate it
        if fm.fileExists(atPath: oldBackup.path) && !fm.fileExists(atPath: newBackup1.path) {
            do {
                try fm.moveItem(at: oldBackup, to: newBackup1)
                setSecurePermissions(for: newBackup1)
                print("✅ Migrated old backup format for \(fileURL.lastPathComponent)")
            } catch {
                print("⚠️ Failed to migrate old backup: \(error)")
            }
        }
    }

    /// Rotate backups: 5→delete, 4→5, 3→4, 2→3, 1→2, current→1
    /// Keeps up to 5 generations of backups for disaster recovery
    /// ATOMIC: Uses temp directory to ensure all-or-nothing rotation
    private func rotateBackups(for fileURL: URL) {
        let fm = FileManager.default

        // Only rotate if the source file exists
        guard fm.fileExists(atPath: fileURL.path) else { return }

        // Migrate old single backup if present
        migrateOldBackup(for: fileURL)

        // Create temp directory for atomic rotation
        let tempDir = fileURL.deletingLastPathComponent().appendingPathComponent("backup_temp_\(UUID().uuidString)")

        do {
            // PHASE 1: Copy all backups to temp directory (atomic prep)
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Copy existing backups to temp (4→5, 3→4, 2→3, 1→2)
            for generation in stride(from: 4, through: 1, by: -1) {
                let sourceBackup = fileURL.appendingPathExtension("backup.\(generation)")
                let tempBackup = tempDir.appendingPathComponent(fileURL.lastPathComponent).appendingPathExtension("backup.\(generation + 1)")

                if fm.fileExists(atPath: sourceBackup.path) {
                    try fm.copyItem(at: sourceBackup, to: tempBackup)
                }
            }

            // Copy current file as backup.1
            let tempBackup1 = tempDir.appendingPathComponent(fileURL.lastPathComponent).appendingPathExtension("backup.1")
            try fm.copyItem(at: fileURL, to: tempBackup1)
            setSecurePermissions(for: tempBackup1)

            // PHASE 2: Delete old backups (now safe, we have copies)
            for generation in 1...5 {
                let oldBackup = fileURL.appendingPathExtension("backup.\(generation)")
                try? fm.removeItem(at: oldBackup)
            }

            // PHASE 3: Move new backups from temp to real location
            let tempContents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for tempFile in tempContents {
                let destination = fileURL.deletingLastPathComponent().appendingPathComponent(tempFile.lastPathComponent)
                try fm.moveItem(at: tempFile, to: destination)
                setSecurePermissions(for: destination)
            }

            // Clean up temp directory
            try? fm.removeItem(at: tempDir)

        } catch {
            print("⚠️ Atomic backup rotation failed for \(fileURL.lastPathComponent): \(error)")
            // Clean up temp directory on failure
            try? fm.removeItem(at: tempDir)

            // Fall back to simple single backup (better than nothing)
            let backup1 = fileURL.appendingPathExtension("backup.1")
            try? fm.removeItem(at: backup1)
            try? fm.copyItem(at: fileURL, to: backup1)
            setSecurePermissions(for: backup1)
        }
    }

    /// Attempt to restore from backups, trying .1, .2, .3, .4, .5 in order
    /// Returns restored data or nil if all backups fail
    /// Validates JSON before returning to ensure backup is not corrupt
    private func restoreFromBackups(for fileURL: URL) -> Data? {
        let fm = FileManager.default

        for generation in 1...5 {
            let backupFile = fileURL.appendingPathExtension("backup.\(generation)")

            if fm.fileExists(atPath: backupFile.path) {
                do {
                    let data = try Data(contentsOf: backupFile)

                    // CRITICAL: Validate JSON before returning
                    // Ensures backup is not corrupt (e.g., incomplete write, disk corruption)
                    _ = try JSONDecoder().decode([QuickNote].self, from: data)

                    print("✅ Restored and validated notes from backup generation \(generation)")
                    return data
                } catch {
                    print("⚠️ Notes backup generation \(generation) failed validation: \(error)")
                    // Try next generation
                }
            }
        }

        return nil // All backups failed
    }

    private func loadNotes() {
        guard FileManager.default.fileExists(atPath: notesFile.path) else { return }

        ioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try Data(contentsOf: self.notesFile)
                let loadedNotes = try JSONDecoder().decode([QuickNote].self, from: data)

                DispatchQueue.main.async {
                    self.notes = loadedNotes.sorted { note1, note2 in
                        if note1.isPinned != note2.isPinned {
                            return note1.isPinned  // Pinned first
                        }
                        return note1.timestamp > note2.timestamp  // Newest first
                    }
                }
            } catch {
                print("⚠️ Failed to load notes: \(error)")

                // Attempt to restore from backups (tries .1, .2, .3, .4, .5)
                print("🔄 Attempting to restore notes from backups...")
                if let backupData = self.restoreFromBackups(for: self.notesFile) {
                    do {
                        let loadedNotes = try JSONDecoder().decode([QuickNote].self, from: backupData)

                        DispatchQueue.main.async {
                            self.notes = loadedNotes.sorted { note1, note2 in
                                if note1.isPinned != note2.isPinned {
                                    return note1.isPinned
                                }
                                return note1.timestamp > note2.timestamp
                            }
                            print("✅ Restored \(loadedNotes.count) notes from backup")
                        }

                        // Notify user of successful recovery
                        self.showWarningAlert(
                            title: "Notes Recovered",
                            message: "Your notes were corrupted but have been restored from a backup (\(loadedNotes.count) notes recovered)."
                        )
                    } catch {
                        print("⚠️ All notes backup restorations failed: \(error)")
                        self.showCriticalAlert(
                            title: "Data Recovery Failed",
                            message: "Notes could not be loaded and all backups are corrupted. Starting with empty notes."
                        )
                    }
                } else {
                    self.showCriticalAlert(
                        title: "Notes Load Failed",
                        message: "Could not load notes and no backups were found. Starting with empty notes."
                    )
                }
            }
        }
    }

    private func saveNotes() {
        // Debounced save
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveNotesImmediately()
        }
    }

    func saveNotesImmediately() {
        let notesToSave = notes

        ioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(notesToSave)

                // Check disk space before saving (account for 5 backups)
                guard self.hasEnoughDiskSpace(requiredBytes: Int64(data.count)) else {
                    print("⚠️ Insufficient disk space to save notes (\(data.count) bytes)")
                    self.showCriticalAlert(
                        title: "Disk Space Critical",
                        message: "Cannot save notes. Your disk is nearly full. Please free up space to prevent data loss."
                    )
                    return
                }

                // Rotate backups before saving (keeps 5 generations)
                self.rotateBackups(for: self.notesFile)

                try data.write(to: self.notesFile, options: .atomic)
                self.setSecurePermissions(for: self.notesFile)
                print("✅ Saved \(notesToSave.count) notes")
            } catch {
                print("⚠️ Failed to save notes: \(error)")
                self.showCriticalAlert(
                    title: "Save Failed",
                    message: "Could not save notes: \(error.localizedDescription)\n\nYour notes may be lost if the app crashes."
                )
            }
        }
    }

    // MARK: - CRUD Operations

    func addNote(key: String, value: String, pinned: Bool = false) {
        let note = QuickNote(key: key, value: value, isPinned: pinned)
        DispatchQueue.main.async { [weak self] in
            self?.notes.insert(note, at: 0)
            self?.sortNotes()
            self?.saveNotes()
        }
    }

    func updateNote(_ note: QuickNote, key: String, value: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let index = self.notes.firstIndex(where: { $0.id == note.id }) else { return }

            self.notes[index].key = key
            self.notes[index].value = value
            self.saveNotes()
        }
    }

    func togglePin(_ note: QuickNote) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let index = self.notes.firstIndex(where: { $0.id == note.id }) else { return }

            self.notes[index].isPinned.toggle()
            self.sortNotes()
            self.saveNotes()
        }
    }

    func deleteNote(_ note: QuickNote) {
        DispatchQueue.main.async { [weak self] in
            self?.notes.removeAll { $0.id == note.id }
            self?.saveNotes()
        }
    }

    func clearAllNotes() {
        DispatchQueue.main.async { [weak self] in
            self?.notes.removeAll()
            self?.saveNotes()
        }
    }

    private func sortNotes() {
        notes.sort { note1, note2 in
            if note1.isPinned != note2.isPinned {
                return note1.isPinned  // Pinned first
            }
            return note1.timestamp > note2.timestamp  // Newest first
        }
    }

    // MARK: - Utility

    func copyToClipboard(_ note: QuickNote) {
        // Use silent copy to prevent polluting clipboard history
        ClipboardManager.shared.setClipboardSilently(note.value)
    }

    // MARK: - User Notifications

    /// Show a banner notification to the user (non-blocking)
    private func showNotification(_ message: String) {
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = "FloatyClipshot - Notes"
            notification.informativeText = message
            notification.soundName = nil // Silent notification
            NSUserNotificationCenter.default.deliver(notification)
        }
        print("📋 \(message)")
    }

    /// Show an alert dialog for critical errors (blocking)
    /// SAFE: Only shows modal if app is active, otherwise uses notification
    private func showCriticalAlert(title: String, message: String) {
        DispatchQueue.main.async {
            // Check if app is active to prevent modal deadlock
            if NSApplication.shared.isActive {
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = message
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else {
                // App in background - use notification instead of modal
                let notification = NSUserNotification()
                notification.title = "🚨 \(title)"
                notification.informativeText = message
                notification.soundName = NSUserNotificationDefaultSoundName // Audible for critical
                NSUserNotificationCenter.default.deliver(notification)
                print("⚠️ App in background, sent notification instead of modal: \(title)")
            }
        }
        print("🚨 \(title): \(message)")
    }

    /// Show a warning alert (less severe than critical)
    /// SAFE: Only shows modal if app is active, otherwise uses notification
    private func showWarningAlert(title: String, message: String) {
        DispatchQueue.main.async {
            // Check if app is active to prevent modal deadlock
            if NSApplication.shared.isActive {
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else {
                // App in background - use notification instead of modal
                let notification = NSUserNotification()
                notification.title = "⚠️ \(title)"
                notification.informativeText = message
                notification.soundName = nil
                NSUserNotificationCenter.default.deliver(notification)
                print("⚠️ App in background, sent notification instead of modal: \(title)")
            }
        }
        print("⚠️ \(title): \(message)")
    }
}
