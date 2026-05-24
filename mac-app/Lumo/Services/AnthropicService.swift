import Foundation

/// Streams from Anthropic's `/v1/messages` endpoint (different wire format from OpenAI).
struct AnthropicService: TranslationService {
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !request.apiKey.isEmpty else { throw TranslationError.missingAPIKey }
                    let base = trimmedBaseURL(request.baseURL.isEmpty ? Provider.anthropic.defaultBaseURL : request.baseURL)
                    guard let url = URL(string: base + "/v1/messages") else {
                        throw TranslationError.invalidBaseURL
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue(request.apiKey, forHTTPHeaderField: "x-api-key")
                    urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: Any] = [
                        "model": request.model,
                        "max_tokens": 4096,
                        "system": request.system,
                        "messages": [["role": "user", "content": request.user]],
                        "stream": true,
                    ]
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else { throw TranslationError.invalidResponse }
                    guard (200..<300).contains(http.statusCode) else {
                        throw TranslationError.http(status: http.statusCode, body: await collectBody(bytes))
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue } // ignore "event:" lines
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if let data = payload.data(using: .utf8),
                           let event = try? JSONDecoder().decode(StreamEvent.self, from: data),
                           event.type == "content_block_delta",
                           let text = event.delta?.text, !text.isEmpty {
                            continuation.yield(text)
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

private struct StreamEvent: Decodable {
    struct Delta: Decodable { let text: String? }
    let type: String
    let delta: Delta?
}
