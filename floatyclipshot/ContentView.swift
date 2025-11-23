//
//  ContentView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import SwiftUI
import QuickLook

struct ClipboardHistoryView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @Environment(\.dismiss) var dismiss
    @State private var previewItem: URL?

    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.clipboardHistory
        
        if showFavoritesOnly {
            items = items.filter { $0.isFavorite }
        }
        
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                let textMatch = item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false
                let contextMatch = item.windowContext?.localizedCaseInsensitiveContains(searchText) ?? false
                let displayMatch = item.displayName.localizedCaseInsensitiveContains(searchText)
                return textMatch || contextMatch || displayMatch
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Clipboard History")
                    .font(.headline)
                Spacer()
                
                // Filter Button
                Button(action: { showFavoritesOnly.toggle() }) {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .foregroundColor(showFavoritesOnly ? .yellow : .secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .help("Show Favorites Only")
                .padding(.trailing, 12)
                
                if !clipboardManager.clipboardHistory.isEmpty {
                    Button("Clear All") {
                        clipboardManager.clearHistory()
                    }
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search (e.g. 'Chrome', 'code')", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // List
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: searchText.isEmpty && !showFavoritesOnly ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty && !showFavoritesOnly ? "No history yet" : "No matches found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            } else {
                List {
                    ForEach(filteredItems) { item in
                        HistoryItemRow(item: item)
                            .contextMenu {
                                Button("Copy to Clipboard") {
                                    clipboardManager.pasteItem(item)
                                }
                                Button(item.isFavorite ? "Unstar" : "Star") {
                                    clipboardManager.toggleFavorite(item)
                                }
                                if item.type == ClipboardItemType.image, let url = item.fileURL {
                                    Button("Preview") {
                                        NSWorkspace.shared.open(url)
                                    }
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    }
                                }
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(width: 320, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct HistoryItemRow: View {
    let item: ClipboardItem
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            // Main clickable area (Icon + Text)
            Button(action: {
                ClipboardManager.shared.pasteItem(item)
            }) {
                HStack(spacing: 12) {
                    // Icon / Thumbnail
                    Group {
                        if let thumb = thumbnail {
                            Image(nsImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if item.type == ClipboardItemType.image {
                            ZStack {
                                Color.gray.opacity(0.2)
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            ZStack {
                                Color.blue.opacity(0.1)
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.1), lineWidth: 1))

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        // Title / Content
                        Text(mainText)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(2)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        // Metadata
                        HStack(spacing: 6) {
                            // App Icon/Name
                            if let app = item.windowContext {
                                HStack(spacing: 2) {
                                    Image(systemName: "app.window")
                                        .font(.system(size: 10))
                                    Text(app)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            }

                            // Time
                            Text(timeString)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption2)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain) // Make it look like a normal row, not a button
            
            // Star Button (Separate from main click)
            Button(action: {
                ClipboardManager.shared.toggleFavorite(item)
            }) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundColor(item.isFavorite ? .yellow : .secondary.opacity(0.2))
                    .font(.system(size: 16)) // Slightly larger for easier tapping
                    .padding(4) // larger hit area
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadThumbnail()
        }
    }

    var mainText: String {
        switch item.type {
        case .image: return "Screenshot"
        case .text(let preview): return item.textContent ?? preview
        case .unknown: return "Unknown Item"
        }
    }

    var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.timestamp, relativeTo: Date())
    }

    private func loadThumbnail() {
        guard item.type == ClipboardItemType.image, let url = item.fileURL, thumbnail == nil else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Generate thumbnail efficiently without loading full image
            let options: [String: Any] = [
                kCGImageSourceThumbnailMaxPixelSize as String: 100,
                kCGImageSourceCreateThumbnailFromImageAlways as String: true,
                kCGImageSourceCreateThumbnailWithTransform as String: true
            ]
            
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                let thumb = NSImage(cgImage: cgImage, size: NSSize(width: 50, height: 50))
                DispatchQueue.main.async {
                    self.thumbnail = thumb
                }
            }
        }
    }
}
