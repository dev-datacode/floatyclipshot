//
//  PairingListView.swift
//  floatyclipshot
//
//  Manages universal window-to-window pairings
//  Supports any source (Terminal, IDE, Claude, Slack) to any target (Simulator, Browser, etc.)
//

import SwiftUI

struct PairingListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pairingManager = PairingManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Window Pairings")
                        .font(.title2)
                        .bold()
                    Text("Press Cmd+Shift+B to capture the paired window from any app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Enable/Disable toggle
                Toggle("", isOn: $pairingManager.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding()

            Divider()

            // Pairings list
            if pairingManager.pairings.isEmpty {
                emptyStateView
            } else {
                pairingsListView
            }

            Divider()

            // Footer
            HStack {
                Text("\(pairingManager.pairings.count) pairing\(pairingManager.pairings.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 550, height: 450)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Pairings Yet")
                    .font(.headline)

                Text("To create a pairing:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("1.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Open any app (Terminal, IDE, Claude, Slack, etc.)")
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        Text("2.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Long-press the FloatyClipshot button")
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        Text("3.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Hover over the target window and click the link icon")
                            .font(.caption)
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var pairingsListView: some View {
        List {
            ForEach(pairingManager.pairings) { pairing in
                PairingRow(pairing: pairing)
            }
            .onDelete { offsets in
                pairingManager.deletePairing(at: offsets)
            }
        }
        .listStyle(.inset)
    }
}

struct PairingRow: View {
    let pairing: WindowPairing
    @State private var isHovered = false
    @State private var showingEditSheet = false

    /// Get icon for source app category
    private var sourceIcon: String {
        let category = AppRegistry.category(forAppName: pairing.sourceOwnerName)
        switch category {
        case .terminal: return "terminal"
        case .ide: return "chevron.left.forwardslash.chevron.right"
        case .aiChat: return "bubble.left.and.bubble.right"
        case .messaging: return "message"
        case .browser: return "globe"
        case .documentation: return "doc.text"
        case .ticketing: return "ticket"
        case .design: return "paintbrush"
        case .email: return "envelope"
        case .textEditor: return "text.cursor"
        case .generic: return "app"
        }
    }

    /// Get icon for capture target
    private var captureIcon: String {
        switch pairing.captureOwnerName {
        case "Simulator": return "iphone"
        case "Safari": return "safari"
        case "Google Chrome": return "globe"
        case "Firefox": return "flame"
        case "Arc": return "circle.hexagongrid"
        case "Preview": return "photo"
        default: return "macwindow"
        }
    }

    /// Get paste mode icon
    private var pasteModeIcon: String {
        switch pairing.pasteMode {
        case .filePath: return "doc.text"
        case .image: return "photo"
        case .auto: return "sparkles"
        }
    }

    /// Get paste mode color
    private var pasteModeColor: Color {
        switch pairing.pasteMode {
        case .filePath: return .blue
        case .image: return .purple
        case .auto: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Source side (paste destination)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: sourceIcon)
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                    Text(pairing.sourceOwnerName)
                        .font(.system(size: 11, weight: .medium))
                }
                if !pairing.sourceTitlePattern.isEmpty {
                    Text(pairing.sourceTitlePattern)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Arrow with paste mode indicator
            VStack(spacing: 2) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)

                // Paste mode badge
                HStack(spacing: 2) {
                    Image(systemName: pasteModeIcon)
                        .font(.system(size: 8))
                    Text(pairing.pasteMode.displayName)
                        .font(.system(size: 8))
                }
                .foregroundStyle(pasteModeColor)
            }

            // Capture target side
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text(pairing.captureOwnerName)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: captureIcon)
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
                if !pairing.captureTitlePattern.isEmpty {
                    Text(pairing.captureTitlePattern)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Edit button (shown on hover)
            if isHovered {
                Button(action: { showingEditSheet = true }) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .sheet(isPresented: $showingEditSheet) {
            PairingEditView(pairing: pairing)
        }
    }
}

struct PairingEditView: View {
    let pairing: WindowPairing
    @Environment(\.dismiss) var dismiss

    @State private var sourcePattern: String
    @State private var capturePattern: String
    @State private var pasteMode: PasteMode

    init(pairing: WindowPairing) {
        self.pairing = pairing
        _sourcePattern = State(initialValue: pairing.sourceTitlePattern)
        _capturePattern = State(initialValue: pairing.captureTitlePattern)
        _pasteMode = State(initialValue: pairing.pasteMode)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Pairing")
                .font(.title3)
                .bold()

            // Source pattern (paste destination)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "app.badge")
                        .foregroundStyle(.blue)
                    Text("Source: \(pairing.sourceOwnerName)")
                        .font(.headline)
                    Spacer()
                    Text("Where to paste")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Window title pattern (e.g., project-name)", text: $sourcePattern)
                    .textFieldStyle(.roundedBorder)

                Text("Leave empty to match any window from this app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Capture target pattern
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "camera")
                        .foregroundStyle(.green)
                    Text("Capture: \(pairing.captureOwnerName)")
                        .font(.headline)
                    Spacer()
                    Text("What to screenshot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Window title pattern (e.g., iPhone 15)", text: $capturePattern)
                    .textFieldStyle(.roundedBorder)

                Text("Leave empty to match any window from this app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Paste mode selection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.purple)
                    Text("Paste Mode")
                        .font(.headline)
                }

                Picker("", selection: $pasteMode) {
                    ForEach(PasteMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: pasteModeIcon(for: mode))
                            Text(mode.displayName)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(pasteMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    var updatedPairing = pairing
                    updatedPairing.update(
                        sourceTitlePattern: sourcePattern,
                        captureTitlePattern: capturePattern,
                        pasteMode: pasteMode
                    )
                    PairingManager.shared.updatePairing(updatedPairing)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 450, height: 450)
    }

    private func pasteModeIcon(for mode: PasteMode) -> String {
        switch mode {
        case .filePath: return "doc.text"
        case .image: return "photo"
        case .auto: return "sparkles"
        }
    }
}

// MARK: - Legacy Compatibility View

/// Legacy view wrapper for backwards compatibility
struct TerminalPairingListView: View {
    var body: some View {
        PairingListView()
    }
}

#Preview {
    PairingListView()
}
