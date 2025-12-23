//
//  WindowsDetailView.swift
//  floatyclipshot
//

import SwiftUI
import AppKit

struct WindowsDetailView: View {
    @ObservedObject private var windowManager = WindowManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Windows")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Select a window to capture, or leave empty for full screen.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    windowManager.refreshWindowList()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(24)

            Divider()

            // Current Selection
            if let selected = windowManager.selectedWindow {
                HStack {
                    Image(systemName: "scope")
                        .foregroundStyle(.blue)
                    Text("Currently targeting: \(selected.displayName)")
                        .font(.subheadline)
                    Spacer()
                    Button("Clear") {
                        windowManager.clearSelection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
            }

            // Window List
            List {
                ForEach(windowManager.availableWindows) { window in
                    WindowListRow(
                        window: window,
                        isSelected: windowManager.selectedWindow?.id == window.id,
                        onSelect: {
                            windowManager.selectWindow(window)
                        }
                    )
                }
            }
            .listStyle(.inset)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            windowManager.refreshWindowList()
        }
    }
}
