//
//  ClipboardDetailView.swift
//  floatyclipshot
//

import SwiftUI
import AppKit

struct ClipboardDetailView: View {
    @ObservedObject private var clipboardManager = ClipboardManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard History")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("\(clipboardManager.clipboardHistory.count) items saved")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    clipboardManager.clearHistory()
                }) {
                    Label("Clear All", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(24)

            Divider()

            if clipboardManager.clipboardHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No Clipboard History")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Screenshots you capture will appear here.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(clipboardManager.clipboardHistory) { item in
                            ClipboardCard(item: item) {
                                clipboardManager.pasteItem(item)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
