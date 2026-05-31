import AVFoundation
import Foundation

/// Reads text aloud with the system speech synthesizer, picking a voice
/// based on whether the text is Chinese. Publishes `isSpeaking`/`currentSource`
/// so a specific speak button can show an active "stop" state while *it* is
/// playing.
@MainActor
final class Speaker: NSObject, ObservableObject {
    static let shared = Speaker()

    /// Which control started the current playback. Keyed on instead of the spoken
    /// text so the stop state stays correct even when two controls share the same
    /// text or the text changes under a running playback (e.g. streamed output).
    enum Source: Equatable { case input, result }

    private let synthesizer = AVSpeechSynthesizer()

    @Published private(set) var isSpeaking = false
    /// The control whose text is currently playing (nil when idle).
    @Published private(set) var currentSource: Source?

    /// Identity of the in-flight utterance. The delegate clears state only when
    /// the finishing utterance is still the current one, so restarting playback
    /// (stop-then-speak) doesn't let the old cancel callback wipe the new state.
    private var currentUtterance: AVSpeechUtterance?

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, source: Source) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: LanguageDetector.isChinese(trimmed) ? "zh-CN" : "en-US")
        currentUtterance = utterance
        currentSource = source
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func finish(_ utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        currentUtterance = nil
        currentSource = nil
        isSpeaking = false
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish(utterance) }
    }

    nonisolated func speechSynthesizer(_: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish(utterance) }
    }
}
