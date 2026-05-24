import Foundation
import SwiftData

@Model
final class HistoryItem {
    var createdAt: Date
    var modeRaw: String
    var sourceText: String
    var outputText: String
    var target: String
    var providerRaw: String
    var model: String

    init(createdAt: Date = .now,
         mode: TranslationMode,
         sourceText: String,
         outputText: String,
         target: String,
         provider: Provider,
         model: String) {
        self.createdAt = createdAt
        self.modeRaw = mode.rawValue
        self.sourceText = sourceText
        self.outputText = outputText
        self.target = target
        self.providerRaw = provider.rawValue
        self.model = model
    }

    var mode: TranslationMode { TranslationMode(rawValue: modeRaw) ?? .translate }
    var provider: Provider { Provider(rawValue: providerRaw) ?? .openAI }
}
