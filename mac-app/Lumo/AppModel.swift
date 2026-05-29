import SwiftUI
import AppKit

/// Central app state. Shared singleton so the AppKit delegate (which handles
/// the URL scheme) and the SwiftUI scenes can talk to the same instance.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var request: TranslationRequest?
    @Published var output: String = ""
    @Published var resolvedTarget: String = ""
    @Published var isLoading: Bool = false
    @Published var errorText: String?
    @Published var isPinned: Bool = false

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

    /// Entry point for a hand-off from PopClip.
    func handle(_ request: TranslationRequest) {
        self.request = request
        windowController.present()
        retranslate()
    }

    /// (Re)runs translation for the current request and mode.
    func retranslate() {
        guard let request else { return }
        task?.cancel()
        output = ""
        errorText = nil
        isLoading = true

        let settings = AppSettings.shared
        let target = LanguageDetector.target(
            for: request.text,
            whenChinese: settings.targetWhenChinese,
            otherwise: settings.targetWhenOther
        )
        resolvedTarget = target
        let chat = ChatRequest(
            baseURL: settings.baseURL,
            apiKey: settings.apiKey(for: settings.provider),
            model: settings.model,
            system: request.mode.systemPrompt(target: target),
            user: request.text
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
                        mode: request.mode,
                        sourceText: request.text,
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

    /// Switch mode (from the window picker) and re-run.
    func setMode(_ mode: TranslationMode) {
        guard var request, request.mode != mode else { return }
        request.mode = mode
        self.request = request
        retranslate()
    }
}
