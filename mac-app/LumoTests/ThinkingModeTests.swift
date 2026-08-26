import Foundation
import Testing
@testable import Lumo

@Suite("ThinkingMode")
struct ThinkingModeTests {
    @Test("allCases is off, on")
    func cases() {
        #expect(ThinkingMode.allCases == [.off, .on])
    }
}

@Suite("Provider.supportsThinkingControl")
struct ProviderThinkingControlTests {
    @Test("only chat-completions cloud providers expose the control")
    func matrix() {
        #expect(Provider.openAI.supportsThinkingControl)
        #expect(Provider.openAICompatible.supportsThinkingControl)
        #expect(Provider.anthropic.supportsThinkingControl == false)
        #expect(Provider.appleFoundation.supportsThinkingControl == false)
    }
}

@Suite("openAICompatibleRequestBody")
struct OpenAICompatibleRequestBodyTests {
    private func request(thinking: ThinkingMode) -> ChatRequest {
        ChatRequest(
            baseURL: "http://localhost:11434",
            apiKey: "ollama",
            model: "qwen3.5:latest",
            system: "sys",
            user: "Hello",
            thinking: thinking
        )
    }

    private func userContent(_ body: [String: Any]) -> String? {
        let messages = body["messages"] as? [[String: String]]
        return messages?.last?["content"]
    }

    @Test("off sends reasoning_effort none and think false, without rewriting the user message")
    func offDisables() {
        let body = openAICompatibleRequestBody(request(thinking: .off))
        #expect(body["reasoning_effort"] as? String == "none")
        #expect(body["think"] as? Bool == false)
        #expect(userContent(body) == "Hello")
    }

    @Test("on omits thinking fields and leaves the user message alone")
    func onOmits() {
        let body = openAICompatibleRequestBody(request(thinking: .on))
        #expect(body["reasoning_effort"] == nil)
        #expect(body["think"] == nil)
        #expect(userContent(body) == "Hello")
        #expect(body["model"] as? String == "qwen3.5:latest")
        #expect(body["stream"] as? Bool == true)
    }
}
