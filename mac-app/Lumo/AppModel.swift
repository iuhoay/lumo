import AppKit
import SwiftUI

/// Central app state. Shared singleton so the AppKit delegate (which handles
/// the URL scheme) and the SwiftUI scenes can talk to the same instance.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    /// Editable source text shown in the window's "Original" field — the single
    /// source of truth for what gets translated. Filled by a PopClip / history
    /// hand-off, or typed/pasted directly in input mode.
    @Published var inputText: String = ""
    /// Currently selected action (translate / polish / summarize).
    @Published var mode: TranslationMode = .translate
    @Published var output: String = ""
    @Published var resolvedTarget: String = ""
    @Published var isLoading: Bool = false
    @Published var errorText: String?
    @Published var isPinned: Bool = false
    /// Bumped to ask the view to move keyboard focus into the input field
    /// (e.g. when the window opens empty for a new translation).
    @Published var focusInputToken: Int = 0

    private lazy var windowController = TranslationWindowController(model: self)
    private var task: Task<Void, Never>?

    private init() {}

    /// Toggle "keep window on top".
    func togglePin() {
        isPinned.toggle()
        windowController.setPinned(isPinned)
    }

    /// Hide the floating translation window.
    func dismiss() {
        windowController.close()
    }

    /// Entry point for a hand-off from PopClip (or re-running a history item):
    /// fill the input with the supplied text and translate immediately.
    func handle(_ request: TranslationRequest) {
        inputText = request.text
        mode = request.mode
        windowController.present()
        // Put focus in the editable input (so it's ready to tweak/re-translate)
        // rather than letting a toolbar button take keyboard focus + focus ring.
        focusInputToken &+= 1
        translate()
    }

    /// Open the window empty for manual input ("New Translation…"), then ask the
    /// view to focus the input field so the user can start typing right away.
    func newTranslation() {
        task?.cancel()
        inputText = ""
        output = ""
        errorText = nil
        resolvedTarget = ""
        isLoading = false
        windowController.present()
        focusInputToken &+= 1
    }

    /// (Re)runs translation for the current input text and mode. No-op on blank
    /// input — the Translate button is disabled then, but Cmd+Return or a mode
    /// switch can still route here.
    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        task?.cancel()
        output = ""
        errorText = nil
        isLoading = true

        let settings = AppSettings.shared
        let mode = self.mode
        let target = LanguageDetector.target(
            for: text,
            whenChinese: settings.targetWhenChinese,
            otherwise: settings.targetWhenOther
        )
        resolvedTarget = target
        let chat = ChatRequest(
            baseURL: settings.resolvedBaseURL(for: settings.provider),
            apiKey: settings.apiKey(for: settings.provider),
            model: settings.model,
            system: mode.systemPrompt(target: target),
            user: text
        )
        let service = ServiceFactory.make(for: settings.provider)

        task = Task { [weak self] in
            do {
                for try await delta in service.stream(chat) {
                    if Task.isCancelled { return }
                    self?.output += delta
                }
                if Task.isCancelled { return }
                let finalOutput = self?.output ?? ""
                if !finalOutput.isEmpty {
                    HistoryStore.shared.add(HistoryItem(
                        mode: mode,
                        sourceText: text,
                        outputText: finalOutput,
                        target: target,
                        provider: settings.provider,
                        model: settings.model
                    ))
                }
            } catch {
                if Task.isCancelled { return }
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self?.errorText = message
            }
            self?.isLoading = false
        }
    }

    /// Switch mode (from the window picker). Re-run only when a translation is
    /// already on screen or in flight, so picking a mode in a fresh, empty window
    /// doesn't fire an unwanted request.
    func setMode(_ newMode: TranslationMode) {
        guard mode != newMode else { return }
        mode = newMode
        if isLoading || !output.isEmpty {
            translate()
        }
    }
}
