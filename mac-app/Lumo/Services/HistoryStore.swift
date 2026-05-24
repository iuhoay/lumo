import Foundation
import SwiftData

/// Owns the SwiftData container so non-View code (AppModel) can persist history,
/// while the History window injects the same container for `@Query`.
@MainActor
final class HistoryStore {
    static let shared = HistoryStore()

    let container: ModelContainer

    private init() {
        do {
            container = try ModelContainer(for: HistoryItem.self)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
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
