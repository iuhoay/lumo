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

/// A throwaway @Model standing in for *another* non-sandboxed app's SwiftData
/// store, used to prove the rescue refuses to import from a foreign schema.
@Model
final class ForeignRecord {
    var label: String
    init(label: String) {
        self.label = label
    }
}

@Suite("Legacy shared-store rescue")
struct LegacyStoreRescueTests {
    @MainActor
    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "default.store")
    }

    /// Returns the container (not just its context): a `ModelContext` does not
    /// retain its `ModelContainer`, so the caller must hold the container for the
    /// test's lifetime or the context dangles.
    @MainActor
    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: HistoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A file-backed HistoryItem store (the shape the real legacy store has) is
    /// imported row-for-row into the fresh store.
    @Test @MainActor
    func importsHistoryFromMatchingLegacyStore() throws {
        let legacyURL = tempStoreURL()
        try FileManager.default.createDirectory(
            at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )

        // Seed the legacy store on disk.
        let legacy = try ModelContainer(
            for: HistoryItem.self,
            configurations: ModelConfiguration(url: legacyURL)
        )
        for i in 0 ..< 2 {
            legacy.mainContext.insert(
                HistoryItem(
                    mode: .translate, sourceText: "src-\(i)", outputText: "out-\(i)",
                    target: "English", provider: .openAI, model: "m"
                )
            )
        }
        try legacy.mainContext.save()

        let destination = try inMemoryContainer()
        let imported = HistoryStore.importLegacyHistory(from: legacyURL, into: destination.mainContext)

        #expect(imported == 2)
        let fetched = try destination.mainContext.fetch(FetchDescriptor<HistoryItem>())
        #expect(Set(fetched.map(\.sourceText)) == ["src-0", "src-1"])

        // Non-destructive: the legacy file is left in place.
        #expect(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    /// A store owned by a *different* app (different entity) must be left
    /// untouched — nothing imported, no crash.
    @Test @MainActor
    func skipsForeignSchemaStore() throws {
        let legacyURL = tempStoreURL()
        try FileManager.default.createDirectory(
            at: legacyURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )

        let foreign = try ModelContainer(
            for: ForeignRecord.self,
            configurations: ModelConfiguration(url: legacyURL)
        )
        foreign.mainContext.insert(ForeignRecord(label: "not ours"))
        try foreign.mainContext.save()

        let destination = try inMemoryContainer()
        let imported = HistoryStore.importLegacyHistory(from: legacyURL, into: destination.mainContext)

        #expect(imported == 0)
        #expect(try destination.mainContext.fetch(FetchDescriptor<HistoryItem>()).isEmpty)
    }

    /// No legacy file at all is a clean no-op.
    @Test @MainActor
    func noOpWhenLegacyStoreMissing() throws {
        let destination = try inMemoryContainer()
        let imported = HistoryStore.importLegacyHistory(from: tempStoreURL(), into: destination.mainContext)
        #expect(imported == 0)
        #expect(try destination.mainContext.fetch(FetchDescriptor<HistoryItem>()).isEmpty)
    }
}
