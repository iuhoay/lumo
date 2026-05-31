import Foundation

/// A request handed off from PopClip via the `lumo://` URL scheme.
struct TranslationRequest: Equatable {
    var text: String
    var mode: TranslationMode
}

enum URLRouter {
    /// Parses URLs of the form:
    ///   lumo://translate?mode=translate&text=<percent-encoded>
    ///   lumo://translate?mode=polish&via=clipboard   (text taken from pasteboard)
    ///
    /// `clipboard` is the current pasteboard string, used only when `via=clipboard`
    /// (the long-text fallback, since custom-scheme URLs have a length limit).
    static func parse(_ url: URL, clipboard: String?) -> TranslationRequest? {
        parse(url, clipboard: clipboard, schemes: registeredSchemes)
    }

    /// As `parse(_:clipboard:)`, but with the accepted URL schemes injected so
    /// tests can validate routing without relying on the bundle's registered
    /// schemes. `schemes` are matched case-insensitively (pass lowercased).
    static func parse(_ url: URL, clipboard: String?, schemes: Set<String>) -> TranslationRequest? {
        guard let scheme = url.scheme?.lowercased(),
              schemes.contains(scheme) else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        let mode = TranslationMode(rawValue: value("mode") ?? "translate") ?? .translate

        let rawText = value("via") == "clipboard" ? clipboard : value("text")
        guard let trimmed = rawText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else {
            return nil
        }
        return TranslationRequest(text: trimmed, mode: mode)
    }

    /// Schemes this build registered in its Info.plist — `lumo` for the
    /// release build, `lumo-dev` for the dev build. Read from the bundle
    /// so the router stays environment-agnostic and the scheme is defined once.
    private static let registeredSchemes: Set<String> = {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        return Set(schemes.map { $0.lowercased() })
    }()
}
