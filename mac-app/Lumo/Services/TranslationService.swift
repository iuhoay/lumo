import Foundation

/// A normalized chat request, independent of provider wire format.
struct ChatRequest {
    var baseURL: String
    var apiKey: String
    var model: String
    var system: String
    var user: String
}

enum TranslationError: LocalizedError {
    case missingAPIKey
    case invalidBaseURL
    case http(status: Int, body: String)
    case invalidResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return String(localized: "No API key set. Add one in Settings.")
        case .invalidBaseURL:
            return String(localized: "Invalid Base URL. Check Settings.")
        case .http(let status, let body):
            let detail = Self.friendlyBody(body)
            return "\(String(localized: "Request failed")) (HTTP \(status)): \(detail)"
        case .invalidResponse:
            return String(localized: "Couldn't parse the model response.")
        case .network(let message):
            return "\(String(localized: "Network error")): \(message)"
        }
    }

    /// Pulls a human message out of an OpenAI/Anthropic-style error body.
    private static func friendlyBody(_ body: String) -> String {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            return body.isEmpty ? String(localized: "(no response body)") : body
        }
        return (error["message"] as? String) ?? (error["type"] as? String) ?? body
    }
}

protocol TranslationService {
    /// Streams incremental text deltas until the response completes.
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, Error>
}

enum ServiceFactory {
    static func make(for provider: Provider) -> TranslationService {
        provider == .anthropic ? AnthropicService() : OpenAICompatibleService()
    }
}

/// Trims trailing slashes from a base URL.
func trimmedBaseURL(_ raw: String) -> String {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    while s.hasSuffix("/") { s.removeLast() }
    return s
}

/// Normalizes thrown errors to `TranslationError`.
func asTranslationError(_ error: Error) -> Error {
    if error is TranslationError { return error }
    if let urlError = error as? URLError { return TranslationError.network(urlError.localizedDescription) }
    return TranslationError.network(error.localizedDescription)
}

/// Drains an SSE byte stream's remaining lines into a single string (for error bodies).
func collectBody(_ bytes: URLSession.AsyncBytes) async -> String {
    var body = ""
    if let lines = try? await collectLines(bytes) { body = lines }
    return body
}

private func collectLines(_ bytes: URLSession.AsyncBytes) async throws -> String {
    var body = ""
    for try await line in bytes.lines { body += line + "\n" }
    return body
}
