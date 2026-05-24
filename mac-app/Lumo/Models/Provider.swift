import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case openAICompatible = "openai-compatible"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic (Claude)"
        case .openAICompatible: return "OpenAI-compatible"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com"
        case .anthropic: return "https://api.anthropic.com"
        case .openAICompatible: return "https://api.deepseek.com"
        }
    }

    /// OpenAI and OpenAI-compatible share the Chat Completions wire format.
    var usesChatCompletions: Bool { self != .anthropic }
}
