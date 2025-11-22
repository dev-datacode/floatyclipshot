//
//  QuickNoteView.swift
//  floatyclipshot
//
//  Created by Hooshyar on 11/21/25.
//

import SwiftUI

struct QuickNoteView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var notesManager = NotesManager.shared

    @State private var key: String = ""
    @State private var value: String = ""
    @State private var pinned: Bool = false
    @FocusState private var focusedField: Field?

    let editingNote: QuickNote?

    enum Field: Hashable {
        case key, value
    }

    init(editingNote: QuickNote? = nil) {
        self.editingNote = editingNote
        if let note = editingNote {
            _key = State(initialValue: note.key)
            _value = State(initialValue: note.value)
            _pinned = State(initialValue: note.isPinned)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text(editingNote == nil ? "Quick Note" : "Edit Note")
                .font(.title2)
                .bold()

            // Key/Title field
            TextField("Title or Key (optional)", text: $key)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .key)

            // Value/Content field
            TextEditor(text: $value)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 120)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($focusedField, equals: .value)

            if value.isEmpty && focusedField != .value {
                Text("Enter your note or reminder...")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, -100)
                    .allowsHitTesting(false)
            }

            // Pin toggle
            Toggle("Pin to top", isOn: $pinned)
                .toggleStyle(.checkbox)

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(editingNote == nil ? "Add" : "Save") {
                    saveNote()
                }
                .keyboardShortcut(.return)
                .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            // Auto-focus value field for quick entry
            focusedField = .value
        }
    }

    private func saveNote() {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else { return }

        if let existingNote = editingNote {
            notesManager.updateNote(existingNote, key: trimmedKey, value: trimmedValue)
        } else {
            notesManager.addNote(key: trimmedKey, value: trimmedValue, pinned: pinned)
        }

        dismiss()
    }
}

// MARK: - Notes List View

struct NotesListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var notesManager = NotesManager.shared
    @State private var showingNewNote = false
    @State private var editingNote: QuickNote?
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Notes")
                    .font(.title2)
                    .bold()

                Spacer()

                Button(action: { showingNewNote = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Add new note")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Notes list
            if notesManager.notes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                    Text("Press + to add your first note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(notesManager.notes) { note in
                            NoteRow(note: note, onEdit: {
                                editingNote = note
                            })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            Divider()

            // Footer actions
            HStack(spacing: 12) {
                if !notesManager.notes.isEmpty {
                    Button("Clear All") {
                        showClearConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 500)
        .sheet(isPresented: $showingNewNote) {
            QuickNoteView()
        }
        .sheet(item: $editingNote) { note in
            QuickNoteView(editingNote: note)
        }
        .alert("Clear All Notes?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                notesManager.clearAllNotes()
            }
        } message: {
            Text("This will permanently delete all \(notesManager.notes.count) notes.")
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    @ObservedObject var notesManager = NotesManager.shared
    let note: QuickNote
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Pin indicator
            Image(systemName: note.isPinned ? "pin.fill" : "pin.slash")
                .font(.caption)
                .foregroundColor(note.isPinned ? .orange : .secondary)
                .frame(width: 16)

            // Note content
            VStack(alignment: .leading, spacing: 4) {
                if !note.key.isEmpty {
                    Text(note.key)
                        .font(.headline)
                }
                Text(note.value)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)

                Text(formatTimestamp(note.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            VStack(spacing: 8) {
                Button(action: { notesManager.copyToClipboard(note) }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                Button(action: { notesManager.togglePin(note) }) {
                    Image(systemName: note.isPinned ? "pin.slash" : "pin")
                }
                .buttonStyle(.plain)
                .help(note.isPinned ? "Unpin" : "Pin")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Edit")

                Button(action: { notesManager.deleteNote(note) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .help("Delete")
            }
            .font(.caption)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(note.isPinned ? Color.orange.opacity(0.05) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(note.isPinned ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    QuickNoteView()
        .frame(width: 400, height: 300)
}

#Preview("Notes List") {
    NotesListView()
}
