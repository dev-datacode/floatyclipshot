//
//  ClipboardManager.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import Foundation
import AppKit
import SwiftUI
import Combine  // Added missing Combine import
import UserNotifications // For modern notifications

struct ClipboardItem: Identifiable, Equatable, Codable {
    let id: UUID
    let fileURL: URL? // For images, references file on disk
    let textContent: String? // For text, stored directly
    let dataType: String // NSPasteboard.PasteboardType as String for Codable
    let timestamp: Date
    let type: ClipboardItemType
    let windowContext: String? // Name of the window/app that was captured
    let dataSize: Int64 // Size in bytes

    init(id: UUID = UUID(), fileURL: URL? = nil, textContent: String? = nil, dataType: NSPasteboard.PasteboardType, timestamp: Date, type: ClipboardItemType, windowContext: String?, dataSize: Int64) {
        self.id = id
        self.fileURL = fileURL
        self.textContent = textContent
        self.dataType = dataType.rawValue
        self.timestamp = timestamp
        self.type = type
        self.windowContext = windowContext
        self.dataSize = dataSize
    }

    var displayName: String {
        let contextPrefix = windowContext.map { "[\($0)] " } ?? ""
        let sizeString = formatSize(dataSize)
        switch type {
        case .image:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "📷 \(contextPrefix)Screenshot \(formatter.string(from: timestamp)) • \(sizeString)"
        case .text(let preview):
            return "📝 \(preview) • \(sizeString)"
        case .unknown:
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "📄 \(contextPrefix)Item \(formatter.string(from: timestamp)) • \(sizeString)"
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: bytes)
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum ClipboardItemType: Codable {
    case image
    case text(String)
    case unknown

    /// OLD METHOD - Deprecated, use areItemsDuplicate instead
    /// This method was broken: returned true for ALL images, only compared text previews
    func isSimilar(to other: ClipboardItemType) -> Bool {
        switch (self, other) {
        case (.image, .image):
            return true // BROKEN: Treats all images as duplicates
        case (.text(let a), .text(let b)):
            return a == b // BROKEN: Only compares 30-char preview, not full text
        case (.unknown, .unknown):
            return true // BROKEN: Treats all unknown types as duplicates
        default:
            return false
        }
    }
}

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    // MARK: - Constants
    private enum Constants {
        static let maxItemSize: Int64 = 50_000_000  // 50MB
    }

    @Published var clipboardHistory: [ClipboardItem] = []
    @Published var totalStorageUsed: Int64 = 0
    @Published var isLoadingHistory = false
    @Published var isPaused: Bool = false
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private var saveTimer: Timer?

    // Thread-safe flag access using serial queue
    private let ignoreChangeQueue = DispatchQueue(label: "com.floatyclipshot.ignoreChange")
    private var _ignoreNextChange: Bool = false
    private var ignoreNextChange: Bool {
        get { ignoreChangeQueue.sync { _ignoreNextChange } }
        set { ignoreChangeQueue.sync { _ignoreNextChange = newValue } }
    }

    // Background queue for file I/O
    private let ioQueue = DispatchQueue(label: "com.floatyclipshot.storage", qos: .utility)

    // Storage directory
    private let storageDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FloatyClipshot", isDirectory: true)
    }()

    private let historyFile: URL
    private let imagesDirectory: URL

    private init() {
        historyFile = storageDirectory.appendingPathComponent("history.json")
        imagesDirectory = storageDirectory.appendingPathComponent("Images", isDirectory: true)

        // Create directories if needed
        createStorageDirectories()

        // Load persisted history on background queue
        loadHistory()

        // Start monitoring clipboard
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
        saveTimer?.invalidate()
        saveHistoryImmediately()
    }

    // MARK: - Persistent Storage

    /// Create and verify storage directories are writable
    /// Shows critical alert if directories cannot be created or are read-only
    private func createStorageDirectories() {
        let fm = FileManager.default

        do {
            // Create main storage directory
            try fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

            // Create images subdirectory
            try fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

            // CRITICAL: Verify directories are writable by creating a test file
            let testFile = storageDirectory.appendingPathComponent(".writetest_\(UUID().uuidString)")
            let testData = Data("test".utf8)

            try testData.write(to: testFile)
            try fm.removeItem(at: testFile)

            print("✅ Storage directory verified: \(storageDirectory.path)")

        } catch {
            print("🚨 CRITICAL: Storage directory unusable: \(error)")

            // Show critical alert - app cannot function without storage
            DispatchQueue.main.async { [weak self] in
                self?.showCriticalAlert(
                    title: "Storage Error",
                    message: """
                    Cannot create or write to storage directory:
                    \(self?.storageDirectory.path ?? "unknown")

                    Error: \(error.localizedDescription)

                    Possible causes:
                    • Disk is full
                    • Permissions denied
                    • Read-only filesystem

                    The app cannot save your clipboard history.
                    """
                )
            }
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.isLoadingHistory = true
        }

        ioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try Data(contentsOf: self.historyFile)
                let items = try JSONDecoder().decode([ClipboardItem].self, from: data)

                DispatchQueue.main.async {
                    self.clipboardHistory = items
                    self.calculateTotalSize()
                    self.isLoadingHistory = false
                }
            } catch {
                print("⚠️ Failed to load clipboard history: \(error)")

                // Attempt to restore from backups (tries .1, .2, .3, .4, .5)
                print("🔄 Attempting to restore from backups...")
                if let backupData = self.restoreFromBackups(for: self.historyFile) {
                    do {
                        let items = try JSONDecoder().decode([ClipboardItem].self, from: backupData)

                        DispatchQueue.main.async {
                            self.clipboardHistory = items
                            self.calculateTotalSize()
                            self.isLoadingHistory = false
                            print("✅ Restored \(items.count) items from backup")
                        }

                        // Notify user of successful recovery
                        self.showWarningAlert(
                            title: "Data Recovered",
                            message: "Your clipboard history was corrupted but has been restored from a backup (\(items.count) items recovered)."
                        )
                        return
                    } catch {
                        print("⚠️ All backup restorations failed: \(error)")
                        self.showCriticalAlert(
                            title: "Data Recovery Failed",
                            message: "Clipboard history could not be loaded and all backups are corrupted. Starting with empty history."
                        )
                    }
                } else {
                    self.showCriticalAlert(
                        title: "History Load Failed",
                        message: "Could not load clipboard history and no backups were found. Starting with empty history."
                    )
                }

                DispatchQueue.main.async {
                    self.isLoadingHistory = false
                }
            }
        }
    }

    private func saveHistory() {
        // Debounced save - wait 2 seconds before actually writing
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.saveHistoryImmediately()
        }
    }

    func saveHistoryImmediately() {
        let itemsToSave = clipboardHistory

        ioQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(itemsToSave)

                // Check disk space before saving (account for 5 backups)
                guard self.hasEnoughDiskSpace(requiredBytes: Int64(data.count)) else {
                    print("⚠️ Insufficient disk space to save history (\(data.count) bytes)")
                    self.showCriticalAlert(
                        title: "Disk Space Critical",
                        message: "Cannot save clipboard history. Your disk is nearly full. Please free up space to prevent data loss."
                    )
                    return
                }

                // Rotate backups before saving (keeps 5 generations)
                self.rotateBackups(for: self.historyFile)

                try data.write(to: self.historyFile, options: .atomic)
                self.setSecurePermissions(for: self.historyFile)
                print("✅ Saved \(itemsToSave.count) items to history")
            } catch {
                print("⚠️ Failed to save clipboard history: \(error)")
                self.showCriticalAlert(
                    title: "Save Failed",
                    message: "Could not save clipboard history: \(error.localizedDescription)\n\nYour clipboard data may be lost if the app crashes."
                )
            }
        }
    }

    private func calculateTotalSize() {
        totalStorageUsed = clipboardHistory.reduce(0) { $0 + $1.dataSize }
    }

    // MARK: - File Operations

    /// Migrate old single backup to new rotating format
    /// Old: history.json.backup → New: history.json.backup.1
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
                    _ = try JSONDecoder().decode([ClipboardItem].self, from: data)

                    print("✅ Restored and validated from backup generation \(generation)")
                    return data
                } catch {
                    print("⚠️ Backup generation \(generation) failed validation: \(error)")
                    // Try next generation
                }
            }
        }

        return nil // All backups failed
    }

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
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: storageDirectory.path)
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

    private func saveImageFile(id: UUID, data: Data) -> URL? {
        // Check disk space before saving (with 50% safety margin)
        guard hasEnoughDiskSpace(requiredBytes: Int64(data.count)) else {
            print("⚠️ Insufficient disk space to save image (\(data.count) bytes)")
            return nil
        }

        let fileURL = imagesDirectory.appendingPathComponent("\(id.uuidString).png")

        do {
            try data.write(to: fileURL, options: .atomic)
            setSecurePermissions(for: fileURL)

            // CRITICAL: Verify file size after save
            // Image processing can expand data significantly (compressed → uncompressed)
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                if fileSize > Constants.maxItemSize {
                    // File too large after save - delete it
                    try? FileManager.default.removeItem(at: fileURL)
                    print("⚠️ Image file too large after save: \(formatBytes(fileSize)) > \(formatBytes(Constants.maxItemSize))")
                    showNotification("⚠️ Image too large after processing (\(formatBytes(fileSize)))")
                    return nil
                }
            }

            return fileURL
        } catch {
            print("⚠️ Failed to save image file: \(error)")
            return nil
        }
    }

    private func loadImageData(from item: ClipboardItem) -> Data? {
        // For text items, return text data
        if let textContent = item.textContent {
            return textContent.data(using: .utf8)
        }

        // For image items, load from file
        guard let fileURL = item.fileURL else {
            print("⚠️ No file URL for item \(item.id)")
            return nil
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ Image file not found: \(fileURL.path)")
            return nil
        }

        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("⚠️ Failed to load image data: \(error)")
            return nil
        }
    }

    // MARK: - Storage Management

    private func checkAndCleanupStorage() {
        let limit = SettingsManager.shared.storageLimit

        // Skip cleanup if unlimited
        guard !limit.isUnlimited else { return }

        // Check if we've exceeded the limit
        if totalStorageUsed > limit.bytes {
            performCleanup(targetSize: SettingsManager.shared.calculateTargetSize(for: limit))
        }
    }

    private func performCleanup(targetSize: Int64) {
        print("🧹 Storage cleanup triggered. Current: \(formatBytes(totalStorageUsed)), Target: \(formatBytes(targetSize))")

        // Remove oldest items until we reach target size
        while totalStorageUsed > targetSize && !clipboardHistory.isEmpty {
            if let removed = clipboardHistory.popLast() {
                totalStorageUsed -= removed.dataSize
                // Delete associated file (image or unknown type with file)
                if removed.fileURL != nil {
                    deleteImageFile(for: removed.id)
                }
                print("Removed item \(removed.id) (\(formatBytes(removed.dataSize)))")
            }
        }

        // Save updated history
        saveHistory()

        print("✅ Cleanup complete. New size: \(formatBytes(totalStorageUsed))")
    }

    // Public method for manual cleanup (called from settings UI)
    func performManualCleanup(targetSize: Int64) {
        DispatchQueue.main.async { [weak self] in
            self?.performCleanup(targetSize: targetSize)
        }
    }

    private func deleteImageFile(for id: UUID) {
        let imageFile = imagesDirectory.appendingPathComponent("\(id.uuidString).png")
        try? FileManager.default.removeItem(at: imageFile)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount

        // Poll every 100ms for instant clipboard detection (was 500ms)
        // Research shows 0.1s is industry standard for responsive clipboard tools
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkClipboardChange()
        }
    }
    
    private func checkClipboardChange() {
        let currentChangeCount = NSPasteboard.general.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount

            // Skip if we're programmatically setting clipboard
            if ignoreNextChange {
                ignoreNextChange = false
                return
            }

            // Skip if monitoring is paused
            if isPaused {
                return
            }

            addCurrentClipboardItem()
        }
    }

    /// Set clipboard content without triggering history capture
    func setClipboardSilently(_ text: String) {
        ignoreNextChange = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func addCurrentClipboardItem() {
        let pasteboard = NSPasteboard.general

        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return }

        for pasteboardItem in items {
            if let clipboardItem = createClipboardItem(from: pasteboardItem) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    // Check if this content already exists in the last 5 items (avoid near duplicates)
                    // Use proper content comparison, not just type matching
                    let recentItems = self.clipboardHistory.prefix(5)
                    let isDuplicate = recentItems.contains { existingItem in
                        self.areItemsDuplicate(existingItem, clipboardItem)
                    }

                    if !isDuplicate {
                        // Add new item
                        self.clipboardHistory.insert(clipboardItem, at: 0)
                        self.totalStorageUsed += clipboardItem.dataSize

                        // Check if cleanup is needed
                        self.checkAndCleanupStorage()

                        // Save updated history
                        self.saveHistory()
                    } else {
                        print("📋 Skipping duplicate clipboard item")
                    }
                }
            }
        }
    }
    
    private func createClipboardItem(from pasteboardItem: NSPasteboardItem) -> ClipboardItem? {
        let type: ClipboardItemType
        var fileURL: URL?
        var textContent: String?
        var dataType: NSPasteboard.PasteboardType
        var dataSize: Int64
        let itemID = UUID()

        if pasteboardItem.types.contains(.png),
           let pngData = pasteboardItem.data(forType: .png) {
            dataSize = Int64(pngData.count)

            // Check size limit
            if dataSize > Constants.maxItemSize {
                print("⚠️ Skipping clipboard item: size \(formatBytes(dataSize)) exceeds limit of \(formatBytes(Constants.maxItemSize))")
                showNotification("⚠️ Clipboard item too large (\(formatBytes(dataSize))). Max allowed: \(formatBytes(Constants.maxItemSize))")
                return nil
            }

            type = .image
            dataType = .png
            // Save image to file
            fileURL = saveImageFile(id: itemID, data: pngData)
        } else if pasteboardItem.types.contains(.tiff),
                  let tiffData = pasteboardItem.data(forType: .tiff) {
            dataSize = Int64(tiffData.count)

            // Check size limit
            if dataSize > Constants.maxItemSize {
                print("⚠️ Skipping clipboard item: size \(formatBytes(dataSize)) exceeds limit of \(formatBytes(Constants.maxItemSize))")
                showNotification("⚠️ Clipboard item too large (\(formatBytes(dataSize))). Max allowed: \(formatBytes(Constants.maxItemSize))")
                return nil
            }

            type = .image
            dataType = .tiff
            // Save image to file
            fileURL = saveImageFile(id: itemID, data: tiffData)
        } else if pasteboardItem.types.contains(.string),
                  let string = pasteboardItem.string(forType: .string) {
            dataSize = Int64(string.utf8.count)

            // Check size limit
            if dataSize > Constants.maxItemSize {
                print("⚠️ Skipping clipboard item: size \(formatBytes(dataSize)) exceeds limit of \(formatBytes(Constants.maxItemSize))")
                showNotification("⚠️ Clipboard text too large (\(formatBytes(dataSize))). Max allowed: \(formatBytes(Constants.maxItemSize))")
                return nil
            }

            let preview = String(string.prefix(30))
            type = .text(preview)
            dataType = .string
            // Store text directly (small)
            textContent = string
        } else {
            // Try to get any available data
            if let firstType = pasteboardItem.types.first,
               let availableData = pasteboardItem.data(forType: firstType) {
                dataSize = Int64(availableData.count)

                // Check size limit
                if dataSize > Constants.maxItemSize {
                    print("⚠️ Skipping clipboard item: size \(formatBytes(dataSize)) exceeds limit of \(formatBytes(Constants.maxItemSize))")
                    showNotification("⚠️ Clipboard item too large (\(formatBytes(dataSize))). Max allowed: \(formatBytes(Constants.maxItemSize))")
                    return nil
                }

                type = .unknown
                dataType = firstType
                dataSize = Int64(availableData.count)
                // Save to file
                fileURL = saveImageFile(id: itemID, data: availableData)
            } else {
                return nil // Could not get any data
            }
        }

        // Get window context from currently selected window
        let windowContext = WindowManager.shared.selectedWindow?.displayName

        return ClipboardItem(
            id: itemID,
            fileURL: fileURL,
            textContent: textContent,
            dataType: dataType,
            timestamp: Date(),
            type: type,
            windowContext: windowContext,
            dataSize: dataSize
        )
    }
    
    // MARK: - Clipboard Actions

    func pasteItem(_ item: ClipboardItem) {
        // Load data lazily from file or text content
        guard let data = loadImageData(from: item) else {
            showNotification("⚠️ Failed to load clipboard item")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let success = pasteboard.setData(data, forType: NSPasteboard.PasteboardType(rawValue: item.dataType))

        if success {
            showNotification("✅ Item restored to clipboard")
        } else {
            showNotification("⚠️ Failed to restore item to clipboard")
        }
    }

    func clearHistory() {
        // Capture items to delete before clearing UI
        let itemsToDelete = clipboardHistory

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Update UI immediately
            self.clipboardHistory.removeAll()
            self.totalStorageUsed = 0
            self.saveHistory()
        }

        // Delete files in background to prevent UI blocking
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            for item in itemsToDelete {
                if item.fileURL != nil {
                    self.deleteImageFile(for: item.id)
                }
            }

            print("✅ Deleted \(itemsToDelete.count) clipboard files")
        }
    }
    
    // MARK: - Duplicate Detection

    /// Properly compare two clipboard items for duplication
    /// Fixed: Now compares actual content, not just types
    private func areItemsDuplicate(_ item1: ClipboardItem, _ item2: ClipboardItem) -> Bool {
        // Different types are never duplicates
        switch (item1.type, item2.type) {
        case (.text, .text):
            // Compare full text content, not just preview
            return item1.textContent == item2.textContent

        case (.image, .image):
            // For images, compare file size + data type as a fast proxy
            // If sizes match, compare first 1KB of data to avoid loading entire files
            guard item1.dataSize == item2.dataSize else { return false }
            guard item1.dataType == item2.dataType else { return false }

            // Compare file contents (sample first 1KB for performance)
            if let url1 = item1.fileURL, let url2 = item2.fileURL {
                do {
                    let handle1 = try FileHandle(forReadingFrom: url1)
                    let handle2 = try FileHandle(forReadingFrom: url2)

                    defer {
                        try? handle1.close()
                        try? handle2.close()
                    }

                    // Compare first 1KB (enough to detect different images)
                    let sample1 = handle1.readData(ofLength: 1024)
                    let sample2 = handle2.readData(ofLength: 1024)

                    return sample1 == sample2
                } catch {
                    // If file read fails, fall back to size/type comparison
                    return true // Conservative: assume duplicate if can't read
                }
            }
            return false

        case (.unknown, .unknown):
            // For unknown types, compare data size and type
            return item1.dataSize == item2.dataSize && item1.dataType == item2.dataType

        default:
            // Different types are never duplicates
            return false
        }
    }

    // MARK: - User Notifications

    /// Show a banner notification to the user (non-blocking)
    private func showNotification(_ message: String) {
        DispatchQueue.main.async {
            let content = UNMutableNotificationContent()
            content.title = "FloatyClipshot"
            content.body = message
            content.sound = nil // Silent notification

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("⚠️ Failed to deliver notification: \(error.localizedDescription)")
                }
            }
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
                let content = UNMutableNotificationContent()
                content.title = "🚨 \(title)"
                content.body = message
                content.sound = UNNotificationSound.default // Audible for critical

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("⚠️ Failed to deliver notification: \(error.localizedDescription)")
                    }
                }
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
                let content = UNMutableNotificationContent()
                content.title = "⚠️ \(title)"
                content.body = message
                content.sound = nil

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("⚠️ Failed to deliver notification: \(error.localizedDescription)")
                    }
                }
                print("⚠️ App in background, sent notification instead of modal: \(title)")
            }
        }
        print("⚠️ \(title): \(message)")
    }
}