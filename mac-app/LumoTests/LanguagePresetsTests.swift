import NaturalLanguage
import Testing
@testable import Lumo

// MARK: - LanguagePresets.selection(for:)

@Suite("LanguagePresets.selection")
struct LanguagePresetsSelectionTests {
    @Test("A stored preset name resolves to that preset with empty custom text")
    func storedPreset() {
        let resolved = LanguagePresets.selection(for: "English")
        #expect(resolved.selection == "English")
        #expect(resolved.custom.isEmpty)
    }

    @Test("A stored custom language resolves to the custom tag with the text preserved")
    func storedCustom() {
        let resolved = LanguagePresets.selection(for: "Dutch")
        #expect(resolved.selection == LanguagePresets.customTag)
        #expect(resolved.custom == "Dutch")
    }

    @Test("A case-variant stored value snaps to the canonical preset name")
    func caseInsensitiveSnap() {
        let resolved = LanguagePresets.selection(for: "english")
        #expect(resolved.selection == "English")
        #expect(resolved.custom.isEmpty)
    }

    @Test("An empty stored value resolves to the custom entry with empty text")
    func emptyStored() {
        let resolved = LanguagePresets.selection(for: "")
        #expect(resolved.selection == LanguagePresets.customTag)
        #expect(resolved.custom.isEmpty)
    }

    @Test("Whitespace-only stored value stays in the custom entry")
    func whitespaceStored() {
        let resolved = LanguagePresets.selection(for: "  ")
        #expect(resolved.selection == LanguagePresets.customTag)
        #expect(resolved.custom == "  ")
    }
}

// MARK: - LanguagePresets.canonicalPreset(matching:)

@Suite("LanguagePresets.canonicalPreset")
struct LanguagePresetsCanonicalTests {
    @Test("Matches a preset case-insensitively and returns the canonical name")
    func canonicalMatch() {
        #expect(LanguagePresets.canonicalPreset(matching: "JAPANESE") == "Japanese")
        #expect(LanguagePresets.canonicalPreset(matching: "simplified chinese") == "Simplified Chinese")
    }

    @Test("Returns nil for a language not in the preset list")
    func noMatch() {
        #expect(LanguagePresets.canonicalPreset(matching: "Dutch") == nil)
        #expect(LanguagePresets.canonicalPreset(matching: "") == nil)
    }

    @Test("The custom tag never collides with a preset name")
    func customTagCollision() {
        #expect(LanguagePresets.list.contains(LanguagePresets.customTag) == false)
    }
}

// MARK: - LanguagePresets.nlLanguage(named:)

@Suite("LanguagePresets.nlLanguage")
struct LanguagePresetsNLLanguageTests {
    @Test("Preset names map to NLLanguage", arguments: [
        ("English", NLLanguage.english),
        ("simplified chinese", NLLanguage.simplifiedChinese),
        ("Japanese", NLLanguage.japanese),
    ] as [(String, NLLanguage)])
    func mapsPreset(name: String, language: NLLanguage) {
        #expect(LanguagePresets.nlLanguage(named: name) == language)
    }

    @Test("Custom text is not a preset language")
    func customIsNil() {
        #expect(LanguagePresets.nlLanguage(named: "Dutch") == nil)
        #expect(LanguagePresets.nlLanguage(named: "en") == nil)
    }
}
