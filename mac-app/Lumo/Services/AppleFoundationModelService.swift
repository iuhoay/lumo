import Foundation
import FoundationModels

/// Runs entirely on-device via Apple's Foundation Models framework — no network,
/// no API key. Uses the same system-language model that powers Apple Intelligence.
///
/// `streamResponse(to:)` yields *cumulative* snapshots (each one is the full text
/// generated so far), but `TranslationService` is delta-based, so we emit only the
/// newly-appended suffix on each snapshot.
struct AppleFoundationModelService: TranslationService {
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Bail out with a friendly message before generating if the
                    // model can't run on this Mac (ineligible, AI off, downloading).
                    if case .unavailable(let reason) = SystemLanguageModel.default.availability {
                        throw TranslationError.localModelUnavailable(Self.message(for: reason))
                    }

                    let session = LanguageModelSession { request.system }
                    let options = GenerationOptions(temperature: 0.2)

                    var emitted = 0 // characters already yielded
                    for try await snapshot in session.streamResponse(to: request.user, options: options) {
                        if Task.isCancelled { return }
                        let full = snapshot.content
                        if full.count > emitted {
                            continuation.yield(String(full.dropFirst(emitted)))
                            emitted = full.count
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

    // MARK: - Availability

    /// Live status for the Settings screen: whether the on-device model is ready,
    /// plus a human-readable explanation when it isn't.
    static func availabilityStatus() -> (ok: Bool, message: String) {
        switch SystemLanguageModel.default.availability {
        case .available:
            return (true, String(localized: "On-device model ready. No API key needed."))
        case .unavailable(let reason):
            return (false, message(for: reason))
        }
    }

    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return String(localized: "This Mac doesn't support Apple Intelligence, so the on-device model is unavailable.")
        case .appleIntelligenceNotEnabled:
            return String(localized: "Apple Intelligence is turned off. Enable it in System Settings to use the on-device model.")
        case .modelNotReady:
            return String(localized: "The on-device model is still downloading. Try again in a little while.")
        @unknown default:
            return String(localized: "The on-device model isn't available right now.")
        }
    }
}
