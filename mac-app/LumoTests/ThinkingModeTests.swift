import Foundation
import Testing
@testable import Lumo

@Suite("ThinkingMode")
struct ThinkingModeTests {
    @Test("allCases is auto, off, on")
    func cases() {
        #expect(ThinkingMode.allCases == [.auto, .off, .on])
    }

    @Test("off appends /no_think; auto and on leave the user text alone")
    func appliedUserContent() {
        #expect(ThinkingMode.off.appliedUserContent("Hello") == "Hello\n\n/no_think")
        #expect(ThinkingMode.auto.appliedUserContent("Hello") == "Hello")
        #expect(ThinkingMode.on.appliedUserContent("Hello") == "Hello")
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

    @Test("auto omits thinking fields and leaves the user message alone")
    func autoOmits() {
        let body = openAICompatibleRequestBody(request(thinking: .auto))
        #expect(body["reasoning_effort"] == nil)
        #expect(body["think"] == nil)
        #expect(userContent(body) == "Hello")
        #expect(body["model"] as? String == "qwen3.5:latest")
        #expect(body["stream"] as? Bool == true)
    }

    @Test("off sends reasoning_effort none, think false, and /no_think")
    func offDisables() {
        let body = openAICompatibleRequestBody(request(thinking: .off))
        #expect(body["reasoning_effort"] as? String == "none")
        #expect(body["think"] as? Bool == false)
        #expect(userContent(body) == "Hello\n\n/no_think")
    }

    @Test("on sends reasoning_effort high and think true")
    func onEnables() {
        let body = openAICompatibleRequestBody(request(thinking: .on))
        #expect(body["reasoning_effort"] as? String == "high")
        #expect(body["think"] as? Bool == true)
        #expect(userContent(body) == "Hello")
    }
}
