import Foundation
import SwiftData
import Testing
@testable import Lumo

@Suite("HistoryItem SwiftData round-trip")
struct HistoryStoreTests {
    /// Builds an isolated in-memory container so tests never touch the user's
    /// on-disk store (and never use HistoryStore.shared).
    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HistoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test @MainActor
    func insertSaveFetchRoundTrip() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let item = HistoryItem(
            createdAt: created,
            mode: .translate,
            sourceText: "hello",
            outputText: "你好",
            target: "Simplified Chinese",
            provider: .openAI,
            model: "gpt-4o-mini"
        )
        context.insert(item)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<HistoryItem>())
        #expect(fetched.count == 1)

        let stored = try #require(fetched.first)
        #expect(stored.sourceText == "hello")
        #expect(stored.outputText == "你好")
        #expect(stored.target == "Simplified Chinese")
        #expect(stored.model == "gpt-4o-mini")
        #expect(stored.modeRaw == "translate")
        #expect(stored.providerRaw == "openai")
        #expect(stored.createdAt == created)
    }

    @Test @MainActor
    func deleteEmptiesTheStore() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let item = HistoryItem(
            mode: .polish,
            sourceText: "draft",
            outputText: "polished draft",
            target: "English",
            provider: .anthropic,
            model: "claude-3-5-sonnet"
        )
        context.insert(item)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<HistoryItem>()).count == 1)

        context.delete(item)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<HistoryItem>()).isEmpty)
    }

    @Test @MainActor
    func multipleItemsRoundTrip() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0 ..< 3 {
            let item = HistoryItem(
                createdAt: base.addingTimeInterval(Double(i)),
                mode: .summarize,
                sourceText: "src-\(i)",
                outputText: "out-\(i)",
                target: "English",
                provider: .openAICompatible,
                model: "deepseek-chat"
            )
            context.insert(item)
        }
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<HistoryItem>())
        #expect(fetched.count == 3)
        #expect(Set(fetched.map(\.sourceText)) == ["src-0", "src-1", "src-2"])
    }

    /// The @Model stores enums by rawValue; the computed accessors must
    /// reconstruct the enum from the raw String.
    @Test @MainActor
    func computedModeAndProviderReconstructFromRawValues() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let item = HistoryItem(
            mode: .polish,
            sourceText: "x",
            outputText: "y",
            target: "English",
            provider: .anthropic,
            model: "m"
        )
        context.insert(item)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<HistoryItem>()).first)
        #expect(stored.mode == .polish)
        #expect(stored.provider == .anthropic)
        #expect(stored.mode.rawValue == stored.modeRaw)
        #expect(stored.provider.rawValue == stored.providerRaw)
    }

    @Test(arguments: TranslationMode.allCases) @MainActor
    func everyModeRoundTrips(_ mode: TranslationMode) throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let item = HistoryItem(
            mode: mode,
            sourceText: "s",
            outputText: "o",
            target: "English",
            provider: .openAI,
            model: "m"
        )
        context.insert(item)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<HistoryItem>()).first)
        #expect(stored.modeRaw == mode.rawValue)
        #expect(stored.mode == mode)
    }

    @Test(arguments: Provider.allCases) @MainActor
    func everyProviderRoundTrips(_ provider: Provider) throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let item = HistoryItem(
            mode: .translate,
            sourceText: "s",
            outputText: "o",
            target: "English",
            provider: provider,
            model: "m"
        )
        context.insert(item)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<HistoryItem>()).first)
        #expect(stored.providerRaw == provider.rawValue)
        #expect(stored.provider == provider)
    }

    /// Unrecognized raw values fall back per the computed accessors:
    /// mode -> .translate, provider -> .openAI.
    @Test @MainActor
    func unknownRawValuesFallBack() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let item = HistoryItem(
            mode: .translate,
            sourceText: "s",
            outputText: "o",
            target: "English",
            provider: .openAI,
            model: "m"
        )
        context.insert(item)
        item.modeRaw = "not-a-mode"
        item.providerRaw = "not-a-provider"
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<HistoryItem>()).first)
        #expect(stored.mode == .translate)
        #expect(stored.provider == .openAI)
    }
}
