import SwiftUI

/// User-configurable settings, persisted in UserDefaults — including the
/// per-provider API keys (see the note below on why not the Keychain).
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var provider: Provider {
        didSet {
            defaults.set(provider.rawValue, forKey: Keys.provider)
            // Swap to the newly-selected provider's OWN base URL so the API key
            // (also per-provider) is never paired with a different provider's
            // host — that would POST one vendor's secret key to another's server.
            baseURL = resolvedBaseURL(for: provider)
        }
    }
    /// Base URL for the CURRENT provider. Backed per-provider (like the API key)
    /// so switching the provider picker swaps the host in lockstep with the key.
    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: baseURLKey(for: provider)) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    /// Thinking / chain-of-thought for OpenAI-compatible hosts (Ollama, Qwen).
    /// Off disables it; On omits the wire fields so the host keeps its default.
    @Published var thinking: ThinkingMode {
        didSet { defaults.set(thinking.rawValue, forKey: Keys.thinking) }
    }
    /// Flip-back language: used only when the input is already in `targetLanguage`.
    /// Storage key stays `nativeLanguage` so existing installs don't remigrate.
    @Published var nativeLanguage: String {
        didSet { defaults.set(nativeLanguage, forKey: Keys.nativeLanguage) }
    }
    /// Default destination. Any language that isn't already this one translates
    /// here; the translation window can override it for one request.
    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }

    private init() {
        let provider = Provider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .openAICompatible
        self.provider = provider
        model = defaults.string(forKey: Keys.model) ?? "deepseek-v4-flash"
        thinking = ThinkingMode(rawValue: defaults.string(forKey: Keys.thinking) ?? "") ?? .off
        // Migrate the legacy two-way model (target per Chinese/non-Chinese
        // input) to native/target: the old "when input IS Chinese →" value is
        // the target language, the old "when input is NOT Chinese →" value is
        // the native language. didSet does NOT fire in init, so persist the
        // migrated values explicitly, then retire the legacy keys.
        let legacyTarget = defaults.string(forKey: LegacyKeys.targetWhenChinese)
        let legacyNative = defaults.string(forKey: LegacyKeys.targetWhenOther)
        nativeLanguage = defaults.string(forKey: Keys.nativeLanguage) ?? legacyNative ?? "Simplified Chinese"
        targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? legacyTarget ?? "English"
        // Resolve the current provider's base URL, migrating any pre-existing
        // single global value (legacy Keys.baseURL) into the current provider.
        let perProvider = defaults.string(forKey: "baseURL.\(provider.rawValue)") ?? ""
        let legacy = defaults.string(forKey: Keys.baseURL) ?? ""
        baseURL = !perProvider.isEmpty ? perProvider
            : (!legacy.isEmpty ? legacy : provider.defaultBaseURL)
        // didSet does NOT fire for assignments inside init, and resolvedBaseURL(for:)
        // reads the persisted slot — so a migrated legacy global would otherwise be
        // shown in Settings yet never actually used (requests would silently hit the
        // vendor default host). Persist the migrated value into the per-provider slot
        // here, then retire the legacy key. Fresh users keep an empty slot so
        // resolvedBaseURL stays on the live provider default.
        if perProvider.isEmpty && !legacy.isEmpty {
            defaults.set(baseURL, forKey: "baseURL.\(provider.rawValue)")
            defaults.removeObject(forKey: Keys.baseURL)
        }
        // Persist the migrated language values (reads of nativeLanguage/
        // targetLanguage are only legal after every stored property is set,
        // hence after baseURL above), then retire the legacy keys.
        defaults.set(nativeLanguage, forKey: Keys.nativeLanguage)
        defaults.set(targetLanguage, forKey: Keys.targetLanguage)
        if legacyTarget != nil || legacyNative != nil {
            defaults.removeObject(forKey: LegacyKeys.targetWhenChinese)
            defaults.removeObject(forKey: LegacyKeys.targetWhenOther)
        }
    }

    // MARK: - Per-provider base URL

    private func baseURLKey(for provider: Provider) -> String { "baseURL.\(provider.rawValue)" }

    /// The stored base URL for a given provider, falling back to its default.
    func resolvedBaseURL(for provider: Provider) -> String {
        let stored = defaults.string(forKey: baseURLKey(for: provider)) ?? ""
        return stored.isEmpty ? provider.defaultBaseURL : stored
    }

    // MARK: - API keys (per provider)
    //
    // Stored in UserDefaults rather than the Keychain: this app is unsigned, so
    // the Keychain can't bind an "Always Allow" grant to a stable code identity
    // and would prompt on every launch. Plaintext-in-prefs is the accepted
    // trade-off for a local personal tool.

    func apiKey(for provider: Provider) -> String {
        defaults.string(forKey: "apiKey.\(provider.rawValue)") ?? ""
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        defaults.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "apiKey.\(provider.rawValue)")
    }

    private enum Keys {
        static let provider = "provider"
        static let baseURL = "baseURL"
        static let model = "model"
        static let thinking = "thinking"
        static let nativeLanguage = "nativeLanguage"
        static let targetLanguage = "targetLanguage"
    }

    /// Pre-rename storage keys, read once for migration in init.
    private enum LegacyKeys {
        static let targetWhenChinese = "targetWhenChinese"
        static let targetWhenOther = "targetWhenOther"
    }
}
