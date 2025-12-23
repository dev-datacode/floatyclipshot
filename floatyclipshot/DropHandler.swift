//
//  DropHandler.swift
//  floatyclipshot
//
//  Created by Claude Code on 12/17/25.
//
//  Handles dropping of various content types onto the floating button.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Capture Type

enum CaptureType {
    case screenshot(WindowInfo?)
    case droppedFile(URL, FileMetadata)
    case droppedText(String)
    case droppedURL(URL)
    case droppedImage(NSImage)
    case droppedCode(String)
}

struct FileMetadata {
    let name: String
    let size: Int64
    let created: Date
    let type: String
}

// MARK: - Drop Handler

class DropHandler {
    static let shared = DropHandler()
    
    private init() {}
    
    /// Process dropped items provider
    func handleDrop(_ providers: [NSItemProvider]) async {
        for provider in providers {
            await processItem(provider)
        }
    }
    
    /// Process a single item provider
    private func processItem(_ item: NSItemProvider) async {
        // 1. Files
        if item.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            await handleFile(item)
        }
        // 2. Images
        else if item.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            await handleImage(item)
        }
        // 3. URLs (Web)
        else if item.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            await handleURL(item)
        }
        // 4. Text / Code
        else if item.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            await handleText(item)
        }
    }
    
    // MARK: - Handlers
    
    private func handleFile(_ item: NSItemProvider) async {
        do {
            let result = try await item.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil)
            
            // Handle both URL and Data representations of file URL
            var fileURL: URL?
            if let url = result as? URL {
                fileURL = url
            } else if let data = result as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                fileURL = url
            }
            
            if let url = fileURL {
                print("📂 Dropped file: \(url.path)")
                addToHistory(url: url)
            }
        } catch {
            print("⚠️ Failed to handle file drop: \(error)")
        }
    }
    
    private func handleImage(_ item: NSItemProvider) async {
        do {
            if let image = try await loadObjectAsync(provider: item, ofClass: NSImage.self) {
                print("🖼️ Dropped image")
                addToHistory(image: image)
            }
        } catch {
            print("⚠️ Failed to handle image drop: \(error)")
        }
    }
    
    private func handleURL(_ item: NSItemProvider) async {
        do {
            if let nsUrl = try await loadObjectAsync(provider: item, ofClass: NSURL.self) {
                let url = nsUrl as URL
                // Distinguish between file URLs and web URLs
                if url.isFileURL {
                    addToHistory(url: url)
                } else {
                    print("🌐 Dropped URL: \(url.absoluteString)")
                    addToHistory(text: url.absoluteString, isURL: true)
                }
            }
        } catch {
            print("⚠️ Failed to handle URL drop: \(error)")
        }
    }
    
    private func handleText(_ item: NSItemProvider) async {
        do {
            if let text = try await item.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) as? String {
                print("📝 Dropped text: \(text.prefix(50))...")
                addToHistory(text: text, isURL: false)
            }
        } catch {
            print("⚠️ Failed to handle text drop: \(error)")
        }
    }
    
    // MARK: - Helper
    
    private func loadObjectAsync<T>(provider: NSItemProvider, ofClass: T.Type) async throws -> T? where T : NSItemProviderReading {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: ofClass) { object, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object as? T)
                }
            }
        }
    }
    
    // MARK: - Integration
    
    @MainActor
    private func addToHistory(image: NSImage) {
        // Convert NSImage to PNG data
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }
        
        // Use ClipboardManager to save image
        // We simulate a pasteboard item for consistent processing
        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)
        
        // This is a bit hacky, better to expose a direct method in ClipboardManager
        // For v1, we'll pipe it through the manager's logic
        ClipboardManager.shared.addDroppedItem(data: pngData, type: .png)
    }
    
    @MainActor
    private func addToHistory(text: String, isURL: Bool) {
        // Store text
        ClipboardManager.shared.addDroppedItem(text: text)
    }
    
    @MainActor
    private func addToHistory(url: URL) {
        // Store file reference
        // Check if it's an image file we can display
        if let image = NSImage(contentsOf: url) {
            addToHistory(image: image)
        } else {
            // Just store path as text for now
            ClipboardManager.shared.addDroppedItem(text: url.path)
        }
    }
}
