import Foundation
import Testing
@testable import Lumo

/// Covers the ⇥-paste feature's only branching logic: `normalizedClipboardText`,
/// which decides whether the empty window shows the "press ⇥ to paste" hint and
/// whether ⇥ acts at all. The surrounding pieces are deliberately NOT unit-tested
/// here — `AppModel.clipboardText` just feeds `NSPasteboard.general` through this
/// function, and `pasteClipboardAndTranslate()` runs on the `AppModel.shared`
/// singleton and dispatches a network task. Exercising those would touch the
/// user's real pasteboard and the network, which this suite avoids on principle
/// (see HistoryStoreTests: isolated state, never the shared singleton).
@Suite("Clipboard ⇥-paste normalization")
struct ClipboardPasteTests {
    @Test("nil clipboard yields nil")
    func nilClipboard() {
        #expect(normalizedClipboardText(nil) == nil)
    }

    @Test("empty string yields nil")
    func emptyString() {
        #expect(normalizedClipboardText("") == nil)
    }

    @Test("whitespace/newline-only text yields nil",
          arguments: ["   ", "\n", "\t", " \n\t ", "\r\n", "\u{00A0}"])
    func whitespaceOnly(raw: String) {
        #expect(normalizedClipboardText(raw) == nil)
    }

    @Test("surrounding whitespace and newlines are trimmed")
    func trimsSurrounding() {
        #expect(normalizedClipboardText("  hello  ") == "hello")
        #expect(normalizedClipboardText("\n\tBonjour\n") == "Bonjour")
        #expect(normalizedClipboardText("translate me\n") == "translate me")
    }

    @Test("internal whitespace and newlines are preserved")
    func preservesInternal() {
        #expect(normalizedClipboardText("hello world") == "hello world")
        #expect(normalizedClipboardText("  line one\nline two  ") == "line one\nline two")
    }

    @Test("clean text passes through unchanged")
    func cleanText() {
        #expect(normalizedClipboardText("Bonjour le monde") == "Bonjour le monde")
    }

    @Test("normalizes via arguments",
          arguments: [
              ("  hello  ", "hello"),
              ("clean", "clean"),
              ("\n\tx\n", "x"),
              ("   ", nil),
              ("", nil),
          ] as [(String, String?)])
    func normalizesViaArguments(raw: String, expected: String?) {
        #expect(normalizedClipboardText(raw) == expected)
    }
}
