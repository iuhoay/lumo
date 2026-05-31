import Foundation
import Testing
@testable import Lumo

/// Tests for the `URLRouter` parsing seam.
///
/// These exercise the internal `parse(_:clipboard:schemes:)` overload so the
/// suite is fully deterministic: the accepted scheme set is injected directly
/// rather than read from `Bundle.main` / the build configuration.
struct URLRoutingTests {
    /// The scheme set injected by every test, mirroring the release build's
    /// registered `lumo://` scheme without depending on the test host bundle.
    static let schemes: Set<String> = ["lumo"]

    private func parse(_ string: String, clipboard: String? = nil) -> TranslationRequest? {
        guard let url = URL(string: string) else {
            Issue.record("Could not build URL from \(string)")
            return nil
        }
        return URLRouter.parse(url, clipboard: clipboard, schemes: Self.schemes)
    }

    // MARK: - Valid translate URLs

    @Test func validTranslateURLWithTextAndMode() {
        let result = parse("lumo://translate?text=Hello&mode=polish")
        #expect(result == TranslationRequest(text: "Hello", mode: .polish))
    }

    @Test(arguments: [
        ("translate", TranslationMode.translate),
        ("polish", TranslationMode.polish),
        ("summarize", TranslationMode.summarize),
    ])
    func everyModeRawValueParses(rawValue: String, expected: TranslationMode) {
        let result = parse("lumo://translate?text=Hi&mode=\(rawValue)")
        #expect(result == TranslationRequest(text: "Hi", mode: expected))
    }

    @Test func modeOmittedDefaultsToTranslate() {
        let result = parse("lumo://translate?text=Hello")
        #expect(result == TranslationRequest(text: "Hello", mode: .translate))
    }

    @Test func unknownModeFallsBackToTranslate() {
        let result = parse("lumo://translate?text=Hello&mode=bogus")
        #expect(result == TranslationRequest(text: "Hello", mode: .translate))
    }

    // MARK: - Clipboard handoff branch (large text)

    @Test func clipboardHandoffUsesClipboardArgument() {
        let big = String(repeating: "x", count: 9000)
        let result = parse("lumo://translate?via=clipboard&mode=summarize", clipboard: big)
        #expect(result == TranslationRequest(text: big, mode: .summarize))
    }

    @Test func clipboardHandoffIgnoresTextQueryParam() {
        // When via=clipboard, the `text` query is ignored in favour of the
        // clipboard contents.
        let result = parse(
            "lumo://translate?via=clipboard&text=ignored",
            clipboard: "from clipboard"
        )
        #expect(result == TranslationRequest(text: "from clipboard", mode: .translate))
    }

    @Test func clipboardHandoffWithNilClipboardYieldsNil() {
        // No clipboard text -> nothing to translate -> nil.
        let result = parse("lumo://translate?via=clipboard", clipboard: nil)
        #expect(result == nil)
    }

    // MARK: - Whitespace handling

    @Test func surroundingWhitespaceIsTrimmed() {
        // %20 = space; surrounding whitespace is stripped from the parsed text.
        let result = parse("lumo://translate?text=%20%20Hello%20world%20%20")
        #expect(result == TranslationRequest(text: "Hello world", mode: .translate))
    }

    @Test func whitespaceOnlyTextIsNil() {
        let result = parse("lumo://translate?text=%20%20%20")
        #expect(result == nil)
    }

    // MARK: - Percent-encoding

    @Test func percentEncodedTextIsDecoded() {
        // "Hello, 世界!" percent-encoded.
        let result = parse("lumo://translate?text=Hello%2C%20%E4%B8%96%E7%95%8C%21&mode=translate")
        #expect(result == TranslationRequest(text: "Hello, 世界!", mode: .translate))
    }

    @Test func percentEncodedInteriorNewlinesPreservedAfterTrim() {
        // Interior newline kept, leading/trailing whitespace trimmed.
        let result = parse("lumo://translate?text=%0Aline1%0Aline2%0A")
        #expect(result == TranslationRequest(text: "line1\nline2", mode: .translate))
    }

    // MARK: - Rejected URLs

    @Test func unregisteredSchemeReturnsNil() {
        let result = parse("notlumo://translate?text=Hello")
        #expect(result == nil)
    }

    @Test func registeredSchemeNotInInjectedSetReturnsNil() {
        // `lumo-dev` is a real Dev-build scheme but is not in the injected set,
        // so it must be rejected here.
        guard let url = URL(string: "lumo-dev://translate?text=Hi") else {
            Issue.record("Could not build lumo-dev URL")
            return
        }
        let result = URLRouter.parse(url, clipboard: nil, schemes: Self.schemes)
        #expect(result == nil)
    }

    @Test func missingTextReturnsNil() {
        let result = parse("lumo://translate?mode=polish")
        #expect(result == nil)
    }

    @Test func emptyTextReturnsNil() {
        let result = parse("lumo://translate?text=")
        #expect(result == nil)
    }

    @Test func schemeMatchingIsCaseInsensitive() {
        // Scheme is lowercased before matching against the injected set.
        let result = parse("LUMO://translate?text=Hello")
        #expect(result == TranslationRequest(text: "Hello", mode: .translate))
    }
}
