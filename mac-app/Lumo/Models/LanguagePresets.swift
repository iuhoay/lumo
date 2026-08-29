import Foundation
import NaturalLanguage

/// LLM-facing language names and the picker resolution that maps a stored
/// string onto (preset selection, custom text). Pure, so the derivation is
/// unit-testable without SwiftUI.
enum LanguagePresets {
    /// Canonical display/prompt names paired with `NLLanguage`. Names are
    /// English on purpose: they are interpolated into the system prompt
    /// ("Translate the user's text into …"), so they must be names the model
    /// understands, not localized labels.
    static let named: [(name: String, language: NLLanguage)] = [
        ("English", .english),
        ("Simplified Chinese", .simplifiedChinese),
        ("Traditional Chinese", .traditionalChinese),
        ("Japanese", .japanese),
        ("Korean", .korean),
        ("French", .french),
        ("German", .german),
        ("Spanish", .spanish),
        ("Portuguese", .portuguese),
        ("Italian", .italian),
        ("Russian", .russian),
        ("Arabic", .arabic),
    ]

    static var list: [String] { named.map(\.name) }

    /// Sentinel tag for the "Custom…" picker entry. Deliberately not a plausible
    /// language name, so a stored custom language can never collide with it.
    static let customTag = "·custom·"

    /// `NLLanguage` for a preset name (case-insensitive). Nil for custom text.
    static func nlLanguage(named name: String) -> NLLanguage? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return named.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }?.language
    }

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
        named.first { $0.name.caseInsensitiveCompare(text) == .orderedSame }?.name
    }
}
