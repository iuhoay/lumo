import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case openAICompatible = "openai-compatible"
    case appleFoundation = "apple-foundation"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic (Claude)"
        case .openAICompatible: return "OpenAI-compatible"
        case .appleFoundation: return "Apple (On-Device)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openAI: return "https://api.openai.com"
        case .anthropic: return "https://api.anthropic.com"
        case .openAICompatible: return "https://api.deepseek.com"
        case .appleFoundation: return "" // on-device: no endpoint
        }
    }

    /// OpenAI and OpenAI-compatible share the Chat Completions wire format.
    var usesChatCompletions: Bool { self != .anthropic }

    /// Apple's on-device model needs no API key, base URL, or model name — the
    /// Settings UI hides those fields and the request fields go unused.
    var isOnDevice: Bool { self == .appleFoundation }
}
