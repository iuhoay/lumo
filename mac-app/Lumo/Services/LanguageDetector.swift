import Foundation
import NaturalLanguage

enum LanguageDetector {
    /// Whether the text is predominantly Chinese.
    static func isChinese(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let language = recognizer.dominantLanguage {
            return language == .simplifiedChinese || language == .traditionalChinese
        }
        // Fallback: any CJK ideograph.
        return text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }

    /// Canonical raw values of every `NLLanguage` case, lowercased. Used to
    /// validate custom-field input, because `NLLanguage(rawValue:)` constructs
    /// successfully for ANY string (it is a struct, not an enum) — without
    /// this whitelist, "Klingon" would silently become a valid language.
    static let validCodes: Set<String> = [
        "af", "ar", "be", "bg", "ca", "cs", "da", "de", "el", "en", "es", "et",
        "fa", "fi", "fr", "he", "hi", "hr", "hu", "id", "it", "ja", "ko", "lt",
        "lv", "ms", "nl", "no", "pl", "pt", "ro", "ru", "sk", "sl", "sr", "sv",
        "th", "tr", "uk", "ur", "vi", "zh-hans", "zh-hant",
    ]

    /// Maps a stored language name — a `LanguagePresets` preset or a raw
    /// `NLLanguage` code ("en", "zh-Hans", "ja") typed into the custom field
    /// — to `NLLanguage`. Nil when the name is unmappable.
    static func languageCode(for name: String) -> NLLanguage? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let language = LanguagePresets.nlLanguage(named: trimmed) {
            return language
        }
        // Accept raw NLLanguage codes as typed in the custom field.
        // NLLanguage(rawValue:) never fails, so gate it on the whitelist;
        // restore the canonical case for the two codes that have one.
        switch trimmed.lowercased() {
        case "zh-hans": return .simplifiedChinese
        case "zh-hant": return .traditionalChinese
        case let code where validCodes.contains(code): return NLLanguage(rawValue: code)
        default: return nil
        }
    }

    /// Whether the text is predominantly in `language`. Simplified and
    /// traditional Chinese count as one family, matching `isChinese`.
    static func isInLanguage(_ text: String, _ language: NLLanguage) -> Bool {
        let chineseFamily = language == .simplifiedChinese || language == .traditionalChinese
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let dominant = recognizer.dominantLanguage {
            if chineseFamily {
                return dominant == .simplifiedChinese || dominant == .traditionalChinese
            }
            return dominant == language
        }
        // Short-string fallback, same as isChinese: any CJK ideograph counts.
        if chineseFamily {
            return text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
        }
        return false
    }

    /// Destination for a translate request: input already in `target` flips to
    /// `fallback`; any other language — including a third language — goes to
    /// `target`. Input is not constrained to the pair.
    ///
    /// An unmappable custom target cannot be detected, so the result is always
    /// `target`. A one-off window override is applied by `resolvedDestination`.
    static func destination(for text: String, target: String, fallback: String) -> String {
        guard let targetCode = languageCode(for: target) else {
            return target
        }
        return isInLanguage(text, targetCode) ? fallback : target
    }

    /// Window-level destination: a non-empty `override` wins (per-request, not
    /// written back to Settings); empty input prefills `target`; otherwise detect.
    static func resolvedDestination(
        text: String,
        target: String,
        fallback: String,
        override: String?
    ) -> String {
        if let override {
            let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty { return target }
        return destination(for: trimmedText, target: target, fallback: fallback)
    }
}
