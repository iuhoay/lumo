import SwiftUI

/// User-configurable settings, persisted in UserDefaults — including the
/// per-provider API keys (see the note below on why not the Keychain).
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var provider: Provider {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }
    @Published var baseURL: String {
        didSet { defaults.set(baseURL, forKey: Keys.baseURL) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }
    /// Target language when the input IS Chinese.
    @Published var targetWhenChinese: String {
        didSet { defaults.set(targetWhenChinese, forKey: Keys.targetWhenChinese) }
    }
    /// Target language when the input is NOT Chinese.
    @Published var targetWhenOther: String {
        didSet { defaults.set(targetWhenOther, forKey: Keys.targetWhenOther) }
    }

    private init() {
        provider = Provider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .openAICompatible
        baseURL = defaults.string(forKey: Keys.baseURL) ?? "https://api.deepseek.com"
        model = defaults.string(forKey: Keys.model) ?? "deepseek-v4-flash"
        targetWhenChinese = defaults.string(forKey: Keys.targetWhenChinese) ?? "English"
        targetWhenOther = defaults.string(forKey: Keys.targetWhenOther) ?? "Simplified Chinese"
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
        static let targetWhenChinese = "targetWhenChinese"
        static let targetWhenOther = "targetWhenOther"
    }
}
