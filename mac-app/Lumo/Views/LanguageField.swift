import SwiftUI

/// A language row for the translate settings: a menu of common languages
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
            } else {
                let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    value = customText
                }
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
                    } else if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        value = newText
                    }
                }
        }
    }
}
