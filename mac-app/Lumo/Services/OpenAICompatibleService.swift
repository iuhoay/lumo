import Foundation

/// Streams from any OpenAI-style `/v1/chat/completions` endpoint
/// (OpenAI, DeepSeek, Moonshot, OpenRouter, Ollama, ...).
struct OpenAICompatibleService: TranslationService {
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !request.apiKey.isEmpty else { throw TranslationError.missingAPIKey }
                    guard let url = URL(string: trimmedBaseURL(request.baseURL) + "/v1/chat/completions") else {
                        throw TranslationError.invalidBaseURL
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("Bearer \(request.apiKey)", forHTTPHeaderField: "Authorization")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONSerialization.data(
                        withJSONObject: openAICompatibleRequestBody(request)
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else { throw TranslationError.invalidResponse }
                    guard (200 ..< 300).contains(http.statusCode) else {
                        throw TranslationError.http(status: http.statusCode, body: await collectBody(bytes))
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
                           let delta = chunk.choices.first?.delta.content, !delta.isEmpty
                        {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: asTranslationError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// JSON body for `/v1/chat/completions`. Off disables thinking; On omits the
/// fields so the host keeps its default (Ollama: on for Qwen 3/3.5).
func openAICompatibleRequestBody(_ request: ChatRequest) -> [String: Any] {
    var body: [String: Any] = [
        "model": request.model,
        "messages": [
            ["role": "system", "content": request.system],
            ["role": "user", "content": request.thinking.appliedUserContent(request.user)]
        ],
        "temperature": 0.2,
        "stream": true
    ]
    if request.thinking == .off {
        body["reasoning_effort"] = "none"
        body["think"] = false
    }
    return body
}

private struct StreamChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }

    let choices: [Choice]
}
