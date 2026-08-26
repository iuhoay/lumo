import SwiftUI

/// Preset target languages for the translate-mode settings, plus the pure
/// resolution logic that maps a stored language string onto (picker selection,
/// custom text). Kept free of SwiftUI so the state derivation is unit-testable.
enum LanguagePresets {
    /// LLM-facing language names — the exact strings embedded in the system
    /// prompt ("Translate the user's text into …"), so they must be names the
    /// model understands in English, not localized display names.
    static let list: [String] = [
        "English",
        "Simplified Chinese",
        "Traditional Chinese",
        "Japanese",
        "Korean",
        "French",
        "German",
        "Spanish",
        "Portuguese",
        "Italian",
        "Russian",
        "Arabic",
    ]

    /// Sentinel tag for the "Custom…" picker entry. Deliberately not a plausible
    /// language name, so a stored custom language can never collide with it.
    static let customTag = "·custom·"

    /// Where the picker should sit for a stored value: a preset tag if the value
    /// is one of the presets (case-insensitively), otherwise the custom tag with
    /// the value as the custom text. Legacy free-text values like "Dutch" or
    /// "english" keep working — the latter snaps to the canonical "English".
    static func selection(for stored: String) -> (selection: String, custom: String) {
        if let preset = canonicalPreset(matching: stored) {
            return (preset, "")
        }
        return (customTag, stored)
    }

    /// If `text` names a preset (case-insensitively), returns the canonical
    /// preset name; otherwise nil. Used to snap the picker back when the user
    /// types a preset into the custom field.
    static func canonicalPreset(matching text: String) -> String? {
        list.first { $0.caseInsensitiveCompare(text) == .orderedSame }
    }
}

/// A target-language row for the translate settings: a menu of common languages
/// with a "Custom…" entry that reveals a free-text field. The stored value is
/// always the plain language name the system prompt receives — presets write
/// their name directly, the custom field writes its text as typed.
struct LanguageField: View {
    let title: LocalizedStringKey
    @Binding var value: String

    @State private var selection: String
    @State private var customText: String

    init(title: LocalizedStringKey, value: Binding<String>) {
        self.title = title
        self._value = value
        let resolved = LanguagePresets.selection(for: value.wrappedValue)
        _selection = State(initialValue: resolved.selection)
        _customText = State(initialValue: resolved.custom)
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(LanguagePresets.list, id: \.self) { language in
                // Plain data string, not a key: the preset names must reach the
                // LLM verbatim, so they are deliberately not localized.
                Text(language).tag(language)
            }
            Text("Custom…").tag(LanguagePresets.customTag)
        }
        .onChange(of: selection) { _, newValue in
            if newValue != LanguagePresets.customTag {
                value = newValue
            }
        }

        if selection == LanguagePresets.customTag {
            TextField(title, text: $customText, prompt: Text("e.g. Dutch"))
                .onChange(of: customText) { _, newText in
                    if let preset = LanguagePresets.canonicalPreset(matching: newText) {
                        // Typed a preset name into the custom field: snap the
                        // menu back to the canonical preset and clear the field.
                        selection = preset
                        customText = ""
                        value = preset
                    } else {
                        value = newText
                    }
                }
        }
    }
}

/// Compact destination control for the translation result row. A quiet chip
/// matching the neighbouring 18pt icon buttons; Custom… uses a popover so the
/// row height doesn't jump.
struct DestinationPicker: View {
    let destination: String
    let onSelect: (String) -> Void

    @State private var showingCustom = false
    @State private var customText = ""

    private var selectedPreset: String? {
        LanguagePresets.canonicalPreset(matching: destination)
    }

    var body: some View {
        Menu {
            Picker("Destination", selection: Binding<String?>(
                get: { selectedPreset },
                set: { if let newValue = $0 { onSelect(newValue) } }
            )) {
                ForEach(LanguagePresets.list, id: \.self) { language in
                    Text(language).tag(Optional(language))
                }
            }
            .labelsHidden()
            .pickerStyle(.inline)
            Divider()
            Button("Custom…") {
                let resolved = LanguagePresets.selection(for: destination)
                customText = resolved.selection == LanguagePresets.customTag ? resolved.custom : ""
                showingCustom = true
            }
        } label: {
            DestinationChip(title: destination)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("Change destination")
        .popover(isPresented: $showingCustom, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom language")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Dutch", text: $customText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitCustom() }
            }
            .padding(12)
            .frame(width: 220)
        }
    }

    private func commitCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSelect(LanguagePresets.canonicalPreset(matching: trimmed) ?? trimmed)
        showingCustom = false
    }
}

/// Quiet language chip: same 18pt row and hover wash as `IconButtonStyle`.
private struct DestinationChip: View {
    let title: String
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 6)
        .frame(height: 18)
        .frame(maxWidth: 168)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.10 : 0))
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
