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

    /// Non-blank text on the general pasteboard, trimmed; `nil` when empty/none.
    /// Drives the empty window's "press ⇥ to paste" hint and the ⇥ shortcut.
    var clipboardText: String? {
        normalizedClipboardText(NSPasteboard.general.string(forType: .string))
    }

    /// ⇥ in the empty window: pull the clipboard in and translate immediately
    /// (same as a PopClip hand-off). No-op once the input has text or when the
    /// clipboard is empty, so a real Tab keeps working after the user types.
    func pasteClipboardAndTranslate() {
        guard inputText.isEmpty, let text = clipboardText else { return }
        inputText = text
        translate()
    }

    /// (Re)runs translation for the current input text and mode. Always cancels
    /// any in-flight request first, so clearing the input mid-stream (then a mode
    /// switch) doesn't leave a stale task running. No-op on blank input.
    func translate() {
        task?.cancel()
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            // Nothing to translate: clear any prior result so a stale output
            // doesn't linger under a now-changed mode label.
            output = ""
            errorText = nil
            resolvedTarget = ""
            isLoading = false
            return
        }
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
    /// already on screen (a result or an error) or in flight, so picking a mode
    /// in a fresh, empty window doesn't fire an unwanted request.
    func setMode(_ newMode: TranslationMode) {
        guard mode != newMode else { return }
        mode = newMode
        if isLoading || !output.isEmpty || errorText != nil {
            translate()
        }
    }
}

/// Normalize raw pasteboard text for the ⇥-paste shortcut: trim surrounding
/// whitespace/newlines and return `nil` when nothing meaningful remains (so a
/// blank or whitespace-only clipboard neither shows the hint nor fires ⇥).
/// A pure free function — like `trimmedBaseURL` — so the logic is unit-testable
/// without reaching into `NSPasteboard.general`.
func normalizedClipboardText(_ raw: String?) -> String? {
    let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (text?.isEmpty == false) ? text : nil
}
