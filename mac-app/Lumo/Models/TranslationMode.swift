import Foundation

/// What the LLM should do with the selected text.
enum TranslationMode: String, CaseIterable, Identifiable {
    case translate
    case polish
    case summarize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .translate: return String(localized: "Translate")
        case .polish: return String(localized: "Polish")
        case .summarize: return String(localized: "Summarize")
        }
    }

    var symbol: String {
        switch self {
        case .translate: return "character.bubble"
        case .polish: return "wand.and.stars"
        case .summarize: return "text.append"
        }
    }

    /// System prompt for this mode. `target` is the resolved target language name.
    func systemPrompt(target: String) -> String {
        switch self {
        case .translate:
            return """
            You are a professional translator. Translate the user's text into \(target). \
            Output only the translation, with no explanations, no quotation marks, and no extra text. \
            Preserve line breaks, inline code, URLs, and the punctuation style of the target language.
            """
        case .polish:
            return """
            You are a professional writing editor. Improve the user's text for clarity, grammar, \
            tone, and natural flow while keeping the original language and meaning. \
            Output only the improved text, with no explanations or quotation marks.
            """
        case .summarize:
            return """
            You are a concise summarizer. Summarize the user's text in \(target), \
            capturing the key points faithfully. Output only the summary, with no preamble.
            """
        }
    }
}
