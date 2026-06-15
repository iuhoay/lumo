import CoreData
import Foundation
import SwiftData

/// Owns the SwiftData container so non-View code (AppModel) can persist history,
/// while the History window injects the same container for `@Query`.
///
/// The store is pinned to a per-app URL
/// (`Application Support/<bundle-id>/Lumo.store`). The SwiftData default for a
/// non-sandboxed app is the *shared* `Application Support/default.store`, which
/// every other non-sandboxed app using a bare `ModelContainer` also writes to.
/// When one of them opens that file with a different schema, Core Data recreates
/// the store and silently drops our `HistoryItem` table — i.e. the user's whole
/// history vanishes. A bundle-id-scoped path can't collide with another app, and
/// also keeps the Debug ("Lumo Dev") and Release stores apart.
@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    let container: ModelContainer

    private init() {
        do {
            let storeURL = Self.storeURL()
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let isNewStore = !FileManager.default.fileExists(atPath: storeURL.path)

            container = try ModelContainer(
                for: HistoryItem.self,
                configurations: ModelConfiguration(url: storeURL)
            )

            // Carry forward any history still living in the old shared store the
            // first time the dedicated store is created, so existing installs
            // don't see an empty list after updating.
            if isNewStore {
                Self.importLegacyHistory(from: Self.legacySharedStoreURL, into: container.mainContext)
            }
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    /// Dedicated, per-app on-disk location for the history database.
    static func storeURL() -> URL {
        let appID = Bundle.main.bundleIdentifier ?? "com.iuhoay.lumo"
        return URL.applicationSupportDirectory
            .appending(path: appID, directoryHint: .isDirectory)
            .appending(path: "Lumo.store")
    }

    /// The legacy SwiftData default for a non-sandboxed app — the shared file we
    /// migrated away from.
    static let legacySharedStoreURL = URL.applicationSupportDirectory.appending(path: "default.store")

    /// One-time, best-effort import of history from `legacyURL` into `context`.
    ///
    /// Deliberately non-destructive: the legacy file is opened read-only and
    /// never deleted, because the shared `default.store` may belong to a
    /// *different* non-sandboxed app. We first confirm via the store's Core Data
    /// metadata that it actually holds our `HistoryItem` entity — if it holds
    /// another app's schema, we touch nothing. Any failure is swallowed: the
    /// rescue is a courtesy, not a correctness requirement.
    @discardableResult
    static func importLegacyHistory(from legacyURL: URL, into context: ModelContext) -> Int {
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return 0 }

        // Read-only metadata probe — does NOT migrate or mutate the store.
        guard
            let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType, at: legacyURL
            ),
            let entityHashes = metadata[NSStoreModelVersionHashesKey] as? [String: Any],
            entityHashes.keys.contains("HistoryItem")
        else { return 0 }

        guard
            let legacy = try? ModelContainer(
                for: HistoryItem.self,
                configurations: ModelConfiguration(url: legacyURL, allowsSave: false)
            )
        else { return 0 }

        let legacyContext = ModelContext(legacy)
        guard
            let items = try? legacyContext.fetch(FetchDescriptor<HistoryItem>()),
            !items.isEmpty
        else { return 0 }

        for item in items {
            context.insert(
                HistoryItem(
                    createdAt: item.createdAt,
                    mode: item.mode,
                    sourceText: item.sourceText,
                    outputText: item.outputText,
                    target: item.target,
                    provider: item.provider,
                    model: item.model
                )
            )
        }
        try? context.save()
        return items.count
    }

    func add(_ item: HistoryItem) {
        container.mainContext.insert(item)
        try? container.mainContext.save()
    }

    func delete(_ item: HistoryItem) {
        container.mainContext.delete(item)
        try? container.mainContext.save()
    }
}
