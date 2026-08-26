import Foundation

/// Whether hybrid thinking models (Qwen 3/3.5, etc.) may think before answering.
/// Off (default) disables thinking on the wire. On omits the fields so the host
/// keeps its default — Ollama enables thinking for those models.
enum ThinkingMode: String, CaseIterable, Identifiable {
    case off
    case on

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .off: return String(localized: "Off")
        case .on: return String(localized: "On")
        }
    }
}
