import Foundation

/// Whether to ask a hybrid thinking model (Qwen 3/3.5, etc.) to think before
/// answering. `auto` omits the wire fields so the host keeps its default —
/// Ollama enables thinking for those models.
enum ThinkingMode: String, CaseIterable, Identifiable {
    case auto
    case off
    case on

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .auto: return String(localized: "Auto")
        case .off: return String(localized: "Off")
        case .on: return String(localized: "On")
        }
    }

    /// Qwen chat-template switch. Only applied when Off so other models don't
    /// see a stray `/no_think` token.
    func appliedUserContent(_ user: String) -> String {
        switch self {
        case .off:
            return user + "\n\n/no_think"
        case .auto, .on:
            return user
        }
    }
}
