import Foundation
import Testing
@testable import Lumo

/// Black-box streaming + SSE parsing tests for `OpenAICompatibleService` and
/// `AnthropicService`. No real network: a `URLProtocol` subclass intercepts
/// `URLSession.shared.bytes(for:)` (both services use the shared session, which
/// honors globally registered protocol classes) and replays a queued response.
///
/// NOTE on the session seam: the contract reports both services hit
/// `URLSession.shared.bytes(for:)` with no injectable session. Registering a
/// protocol class globally is therefore the only interception point, and it
/// works because the default session config includes registered protocol
/// classes. If the services are ever refactored to use a custom
/// `URLSession(configuration:)` that omits `protocolClasses`, these tests would
/// need a session-injection seam instead.
@Suite(.serialized)
struct StreamParsingTests {
    // MARK: - Stub plumbing

    /// One queued canned response for the next intercepted request.
    struct StreamParsingStubResponse {
        let statusCode: Int
        let headers: [String: String]
        /// Body emitted as discrete chunks to simulate streaming. Each chunk is
        /// delivered via `client?.urlProtocol(self, didLoad:)`.
        let chunks: [Data]
    }

    /// A `URLProtocol` that replays a FIFO queue of canned responses and streams
    /// their body chunks one at a time. Uniquely named to avoid colliding with
    /// other suites' stubs.
    final class StreamParsingURLProtocolStub: URLProtocol {
        /// FIFO queue of responses; each intercepted request pops the front.
        nonisolated(unsafe) static var queue: [StreamParsingStubResponse] = []

        static func enqueue(_ response: StreamParsingStubResponse) {
            queue.append(response)
        }

        /// JSON body of the most recent intercepted request. Snapshotted in
        /// `startLoading` because URLSession often puts the payload on
        /// `httpBodyStream` and that stream is consumed by the time the test
        /// resumes.
        nonisolated(unsafe) static var lastJSONBody: [String: Any]?

        static func reset() {
            queue.removeAll()
            lastJSONBody = nil
        }

        /// The host this suite's `ChatRequest`s target. Used to scope interception.
        static let interceptedHost = "example.test"

        override class func canInit(with request: URLRequest) -> Bool {
            // Only intercept this suite's own requests. Returning `true` for every
            // request would capture all URLSession traffic in the test process
            // while registered — including the host app's Sparkle update check.
            request.url?.host == interceptedHost
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            Self.lastJSONBody = Self.readJSONBody(from: request)
            guard let client else { return }

            guard !Self.queue.isEmpty else {
                client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            let canned = Self.queue.removeFirst()

            let url = request.url ?? URL(string: "https://invalid.test")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: canned.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: canned.headers
            )!
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            // Emit each body chunk separately to simulate a streamed response.
            for chunk in canned.chunks {
                client.urlProtocol(self, didLoad: chunk)
            }

            client.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        private static func readJSONBody(from request: URLRequest) -> [String: Any]? {
            let data: Data
            if let body = request.httpBody {
                data = body
            } else if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var collected = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let read = stream.read(&buffer, maxLength: buffer.count)
                    guard read > 0 else { break }
                    collected.append(buffer, count: read)
                }
                data = collected
            } else {
                return nil
            }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }

    // MARK: - Suite lifecycle

    init() {
        URLProtocol.registerClass(StreamParsingURLProtocolStub.self)
        StreamParsingURLProtocolStub.reset()
    }

    // Swift Testing calls `deinit` after each test instance is torn down.
    // (Swift structs cannot have deinit; see the cleanup helper below instead.)

    // MARK: - Helpers

    /// Builds a `ChatRequest` matching the real struct's memberwise init.
    private func makeRequest(
        baseURL: String = "https://example.test",
        thinking: ThinkingMode = .auto
    ) -> ChatRequest {
        ChatRequest(
            baseURL: baseURL,
            apiKey: "sk-test",
            model: "gpt-4o-mini",
            system: "You are a translation engine.",
            user: "Hello",
            thinking: thinking
        )
    }

    /// Drains an `AsyncThrowingStream<String, Error>` into one concatenated string.
    private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> String {
        var result = ""
        for try await chunk in stream {
            result += chunk
        }
        return result
    }

    /// Encodes a single SSE line (already including its `data: ` prefix) plus a
    /// trailing newline so `bytes.lines` can split it.
    private func sseLine(_ raw: String) -> Data {
        Data((raw + "\n").utf8)
    }

    /// Unregisters the protocol after the suite finishes. Called by the final
    /// test so the global registration doesn't leak into other suites. (Structs
    /// have no deinit; serialized execution guarantees ordering.)
    private func unregister() {
        StreamParsingURLProtocolStub.reset()
        URLProtocol.unregisterClass(StreamParsingURLProtocolStub.self)
    }

    // MARK: - OpenAI

    @Test
    func openAIAssemblesMultipleDeltasFromMultipleChunks() async throws {
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [
                    sseLine(#"data: {"choices":[{"delta":{"content":"Hello"}}]}"#),
                    sseLine(#"data: {"choices":[{"delta":{"content":", "}}]}"#),
                    sseLine(#"data: {"choices":[{"delta":{"content":"world"}}]}"#),
                    sseLine("data: [DONE]")
                ]
            )
        )

        let service = OpenAICompatibleService()
        let output = try await collect(service.stream(makeRequest()))

        #expect(output == "Hello, world")
    }

    @Test
    func openAIReassemblesADataLineSplitAcrossTwoBodyChunks() async throws {
        // A single `data:` line is delivered in two separate body chunks; the
        // line is only completed once the trailing newline arrives, so the
        // line-splitter must buffer across the chunk boundary.
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [
                    Data(#"data: {"choices":[{"delta":{"content":"Spl"#.utf8),
                    Data(("it\"}}]}" + "\n").utf8),
                    sseLine("data: [DONE]")
                ]
            )
        )

        let service = OpenAICompatibleService()
        let output = try await collect(service.stream(makeRequest()))

        #expect(output == "Split")
    }

    @Test
    func openAIHandlesDoneTerminatorAndIgnoresLaterDeltas() async throws {
        // Anything after `data: [DONE]` must be ignored because the loop breaks.
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [
                    sseLine(#"data: {"choices":[{"delta":{"content":"Done"}}]}"#),
                    sseLine("data: [DONE]"),
                    sseLine(#"data: {"choices":[{"delta":{"content":"AFTER"}}]}"#)
                ]
            )
        )

        let service = OpenAICompatibleService()
        let output = try await collect(service.stream(makeRequest()))

        #expect(output == "Done")
    }

    @Test
    func openAIThrowsHTTPErrorOn401WithJSONBody() async throws {
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 401,
                headers: ["Content-Type": "application/json"],
                chunks: [
                    sseLine(#"{"error":{"message":"Invalid API key"}}"#)
                ]
            )
        )

        let service = OpenAICompatibleService()

        await #expect {
            _ = try await self.collect(service.stream(self.makeRequest()))
        } throws: { error in
            guard let translationError = error as? TranslationError,
                  case let .http(status, _) = translationError
            else {
                return false
            }
            return status == 401
        }
    }

    @Test
    func openAIOffThinkingLandsOnTheWire() async throws {
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [sseLine("data: [DONE]")]
            )
        )

        let service = OpenAICompatibleService()
        _ = try await collect(service.stream(makeRequest(thinking: .off)))

        let json = try #require(StreamParsingURLProtocolStub.lastJSONBody)
        #expect(json["reasoning_effort"] as? String == "none")
        #expect(json["think"] as? Bool == false)
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages.last?["content"] == "Hello\n\n/no_think")
    }

    // MARK: - Anthropic

    @Test
    func anthropicAssemblesContentBlockDeltas() async throws {
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [
                    sseLine(#"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Bon"}}"#),
                    sseLine(#"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"jour"}}"#)
                ]
            )
        )

        let service = AnthropicService()
        let output = try await collect(service.stream(makeRequest()))

        #expect(output == "Bonjour")
    }

    @Test
    func anthropicFiltersOutNonContentBlockDeltaEvents() async throws {
        // message_start / content_block_start / message_stop and any event whose
        // type isn't `content_block_delta` must be ignored.
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [
                    sseLine(#"data: {"type":"message_start","message":{"id":"x"}}"#),
                    sseLine(#"data: {"type":"content_block_start","index":0}"#),
                    sseLine(#"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hi"}}"#),
                    sseLine(#"data: {"type":"ping"}"#),
                    sseLine(#"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"!"}}"#),
                    sseLine(#"data: {"type":"message_stop"}"#)
                ]
            )
        )

        let service = AnthropicService()
        let output = try await collect(service.stream(makeRequest()))

        #expect(output == "Hi!")
    }

    @Test
    func anthropicReassemblesADataLineSplitAcrossTwoBodyChunks() async throws {
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [
                    Data(#"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Par"#.utf8),
                    Data(("t\"}}" + "\n").utf8)
                ]
            )
        )

        let service = AnthropicService()
        let output = try await collect(service.stream(makeRequest()))

        #expect(output == "Part")
    }

    @Test
    func anthropicThrowsHTTPErrorOn401WithJSONBody() async throws {
        StreamParsingURLProtocolStub.enqueue(
            StreamParsingStubResponse(
                statusCode: 401,
                headers: ["Content-Type": "application/json"],
                chunks: [
                    sseLine(#"{"error":{"type":"authentication_error","message":"invalid x-api-key"}}"#)
                ]
            )
        )

        let service = AnthropicService()

        await #expect {
            _ = try await self.collect(service.stream(self.makeRequest()))
        } throws: { error in
            guard let translationError = error as? TranslationError,
                  case let .http(status, _) = translationError
            else {
                return false
            }
            return status == 401
        }

        // Last test in the serialized suite: tear down the global registration.
        unregister()
    }
}
