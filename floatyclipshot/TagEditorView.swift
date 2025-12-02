//
//  TagEditorView.swift
//  floatyclipshot
//
//  View for creating and editing window tags
//

import SwiftUI

struct TagEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var tagManager = TagManager.shared

    // If editing an existing tag, this will be set
    var existingTag: WindowTag?

    // Window being tagged (for new tags)
    var window: WindowInfo?

    @State private var projectName: String = ""
    @State private var selectedColor: TagColor = .blue
    @State private var selectedPosition: TagPosition = .topLeft
    @State private var showProjectName: Bool = true
    @State private var windowPattern: String = ""
    @State private var showAdvanced: Bool = false

    var isEditing: Bool { existingTag != nil }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(selectedColor.color)

                Text(isEditing ? "Edit Tag" : "Tag Window")
                    .font(.title2)
                    .bold()

                if let window = window {
                    Text(window.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Divider()

            // Project Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name")
                    .font(.headline)

                TextField("e.g., Client Website, iOS App", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }

            // Color Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Tag Color")
                    .font(.headline)

                TagColorPicker(selectedColor: $selectedColor)
            }

            // Position Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(.headline)

                Picker("Position", selection: $selectedPosition) {
                    ForEach(TagPosition.allCases) { position in
                        Label(position.displayName, systemImage: position.icon)
                            .tag(position)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Show Name Toggle
            Toggle(isOn: $showProjectName) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Project Name")
                        .font(.body)
                    Text("Display name alongside color indicator")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Advanced Settings (Window Matching)
            DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(existingTag?.ownerName ?? window?.ownerName ?? "Unknown")
                            .font(.body)
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Title Pattern")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., MyProject, client-website", text: $windowPattern)
                            .textFieldStyle(.roundedBorder)
                        Text("Leave empty to match all windows from this app")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }

            Divider()

            // Preview
            VStack(spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)

                FloatingTagView(tag: WindowTag(
                    projectName: projectName.isEmpty ? "Project Name" : projectName,
                    tagColor: selectedColor,
                    ownerName: window?.ownerName ?? "",
                    windowNamePattern: window?.name ?? "",
                    showProjectName: showProjectName,
                    position: selectedPosition
                ))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Spacer()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Spacer()

                if isEditing {
                    Button(role: .destructive) {
                        if let tag = existingTag {
                            tagManager.deleteTag(tag)
                        }
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: {
                    saveTag()
                    dismiss()
                }) {
                    Text(isEditing ? "Save" : "Create Tag")
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380, height: 580)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .glassEffect()
        }
        .onAppear {
            loadExistingTag()
        }
    }

    private func loadExistingTag() {
        if let tag = existingTag {
            projectName = tag.projectName
            selectedColor = tag.tagColor
            selectedPosition = tag.position
            showProjectName = tag.showProjectName
            windowPattern = tag.windowNamePattern
            showAdvanced = !tag.windowNamePattern.isEmpty
        } else if let window = window {
            windowPattern = window.name
        }
    }

    private func saveTag() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if var tag = existingTag {
            // Update existing tag
            tag.update(
                projectName: trimmedName,
                tagColor: selectedColor,
                showProjectName: showProjectName,
                position: selectedPosition,
                windowNamePattern: windowPattern
            )
            tagManager.updateTag(tag)
        } else if let window = window {
            // Create new tag with custom pattern
            let tag = WindowTag(
                projectName: trimmedName,
                tagColor: selectedColor,
                ownerName: window.ownerName,
                windowNamePattern: windowPattern,
                showProjectName: showProjectName,
                position: selectedPosition
            )
            tagManager.addTag(tag)
        }
    }
}

// MARK: - Color Picker

struct TagColorPicker: View {
    @Binding var selectedColor: TagColor

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TagColor.allCases) { color in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedColor = color
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .frame(width: 28, height: 28)
                            .shadow(color: color.color.opacity(0.4), radius: selectedColor == color ? 4 : 0)

                        if selectedColor == color {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                                .frame(width: 28, height: 28)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .scaleEffect(selectedColor == color ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tag List View

struct TagListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var tagManager = TagManager.shared
    @State private var selectedTag: WindowTag?
    @State private var showEditor = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Window Tags")
                        .font(.title2)
                        .bold()
                    Text("\(tagManager.tags.count) tag\(tagManager.tags.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle(isOn: $tagManager.isEnabled) {
                    Text(tagManager.isEnabled ? "Enabled" : "Disabled")
                        .font(.caption)
                }
                .toggleStyle(.switch)
            }
            .padding()

            Divider()

            if tagManager.tags.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No Tags Yet")
                        .font(.headline)

                    Text("Right-click a window in the menu\nto add a project tag")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(tagManager.tags) { tag in
                        TagRowView(tag: tag)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTag = tag
                                showEditor = true
                            }
                    }
                    .onDelete(perform: tagManager.deleteTag)
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer
            HStack {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .glassEffect()
        }
        .sheet(isPresented: $showEditor) {
            if let tag = selectedTag {
                TagEditorView(existingTag: tag)
            }
        }
    }
}

struct TagRowView: View {
    let tag: WindowTag

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(tag.tagColor.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.projectName)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text(tag.ownerName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !tag.windowNamePattern.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(tag.windowNamePattern)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: tag.position.icon)
                .font(.caption)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}

#Preview("Editor - New") {
    TagEditorView(window: WindowInfo(
        id: 1,
        name: "MyProject — Xcode",
        ownerName: "Xcode",
        ownerPID: 12345,
        bounds: .zero
    ))
}

#Preview("Editor - Edit") {
    TagEditorView(existingTag: WindowTag(
        projectName: "Client Website",
        tagColor: .green,
        ownerName: "Visual Studio Code",
        windowNamePattern: "client-website"
    ))
}

#Preview("Tag List") {
    TagListView()
}

#Preview("Color Picker") {
    TagColorPicker(selectedColor: .constant(.blue))
        .padding()
}
