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

    /// The target language name for a translate request, based on the input.
    static func target(for text: String, whenChinese: String, otherwise: String) -> String {
        isChinese(text) ? whenChinese : otherwise
    }
}
