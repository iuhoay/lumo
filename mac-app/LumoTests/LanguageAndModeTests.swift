import Foundation
import Testing
@testable import Lumo

// MARK: - LanguageDetector.isChinese

@Suite("LanguageDetector.isChinese")
struct LanguageDetectorIsChineseTests {
    @Test("Clearly Chinese text is detected as Chinese")
    func clearlyChinese() {
        #expect(LanguageDetector.isChinese("这是一段完全用中文写成的句子，用于语言检测测试。"))
    }

    @Test("Clearly English text is not Chinese")
    func clearlyEnglish() {
        #expect(LanguageDetector.isChinese("This is a sentence written entirely in English for detection.") == false)
    }

    @Test("Predominantly Chinese text with a few English words is detected as Chinese")
    func predominantlyChineseWithSomeEnglish() {
        // isChinese() classifies by the *dominant* language, so the input must
        // be predominantly Chinese. A balanced ~50/50 mix is intentionally not
        // asserted: NLLanguageRecognizer's dominant pick isn't well-defined there.
        #expect(LanguageDetector.isChinese("这是一段主要由中文写成的文本，其中仅夹杂了 a few English words 而已。"))
    }

    @Test("Empty string is not Chinese")
    func empty() {
        #expect(LanguageDetector.isChinese("") == false)
    }

    @Test("Whitespace-only string is not Chinese")
    func whitespaceOnly() {
        #expect(LanguageDetector.isChinese("   \n\t  ") == false)
    }

    @Test("Digits and punctuation only are not Chinese")
    func digitsAndPunctuation() {
        #expect(LanguageDetector.isChinese("1234567890 !@#$%^&*()-=+[]{};:,.<>/?") == false)
    }

    @Test("A bare CJK ideograph triggers the fallback scan")
    func bareCJKFallback() {
        // Short/ambiguous strings exercise the 0x4E00...0x9FFF fallback path.
        #expect(LanguageDetector.isChinese("汉"))
    }
}

// MARK: - LanguageDetector.target(for:whenChinese:otherwise:)

@Suite("LanguageDetector.target branch selection")
struct LanguageDetectorTargetTests {
    @Test("Chinese input returns the whenChinese branch")
    func chineseBranch() {
        let result = LanguageDetector.target(
            for: "这是中文输入内容，应当走中文分支。",
            whenChinese: "English",
            otherwise: "Simplified Chinese"
        )
        #expect(result == "English")
    }

    @Test("English input returns the otherwise branch")
    func englishBranch() {
        let result = LanguageDetector.target(
            for: "This is English input and should take the otherwise branch.",
            whenChinese: "English",
            otherwise: "Simplified Chinese"
        )
        #expect(result == "Simplified Chinese")
    }

    @Test("Branch labels are returned verbatim regardless of their content")
    func arbitraryLabels() {
        let chinese = LanguageDetector.target(
            for: "完全是中文的一段话用于检测。",
            whenChinese: "TARGET_CN",
            otherwise: "TARGET_OTHER"
        )
        let english = LanguageDetector.target(
            for: "Completely English sentence used for detection.",
            whenChinese: "TARGET_CN",
            otherwise: "TARGET_OTHER"
        )
        #expect(chinese == "TARGET_CN")
        #expect(english == "TARGET_OTHER")
    }
}

// MARK: - TranslationMode.systemPrompt(target:)

@Suite("TranslationMode.systemPrompt")
struct TranslationModeSystemPromptTests {
    @Test("All modes are covered by the case table")
    func tableCoversAllCases() {
        // Guard against new cases being added without prompt coverage here.
        #expect(TranslationMode.allCases.count == 3)
        #expect(Set(TranslationMode.allCases) == Set([.translate, .polish, .summarize]))
    }

    @Test("Every mode produces a non-empty prompt", arguments: TranslationMode.allCases)
    func nonEmptyPrompt(mode: TranslationMode) {
        let prompt = mode.systemPrompt(target: "Simplified Chinese")
        #expect(prompt.isEmpty == false)
    }

    @Test(
        "Target-using modes interpolate the target string",
        arguments: [TranslationMode.translate, TranslationMode.summarize]
    )
    func interpolatesTarget(mode: TranslationMode) {
        let sentinel = "Klingon-XYZ-Target"
        let prompt = mode.systemPrompt(target: sentinel)
        #expect(prompt.contains(sentinel))
    }

    @Test("Polish ignores the target and keeps the original language")
    func polishIgnoresTarget() {
        let prompt = TranslationMode.polish.systemPrompt(target: "Klingon-XYZ-Target")
        #expect(prompt.contains("Klingon-XYZ-Target") == false)
        #expect(prompt.isEmpty == false)
        // Polish is a writing-assistant prompt that preserves the input language.
        #expect(prompt.localizedCaseInsensitiveContains("language"))
    }

    @Test("Translate prompt states a translation intent")
    func translateIntent() {
        let prompt = TranslationMode.translate.systemPrompt(target: "English")
        #expect(prompt.localizedCaseInsensitiveContains("translat"))
        #expect(prompt.contains("English"))
    }

    @Test("All mode prompts preserve structured formatting", arguments: TranslationMode.allCases)
    func promptsPreserveStructuredFormatting(mode: TranslationMode) {
        let prompt = mode.systemPrompt(target: "Simplified Chinese")

        #expect(prompt.localizedCaseInsensitiveContains("paragraph breaks"))
        #expect(prompt.localizedCaseInsensitiveContains("bullet"))
        #expect(prompt.localizedCaseInsensitiveContains("Markdown"))
        #expect(prompt.localizedCaseInsensitiveContains("single paragraph"))
    }

    @Test("Summarize prompt states a summarization intent")
    func summarizeIntent() {
        let prompt = TranslationMode.summarize.systemPrompt(target: "English")
        #expect(prompt.localizedCaseInsensitiveContains("summar"))
        #expect(prompt.contains("English"))
    }

    @Test("Prompts differ per mode for the same target")
    func promptsAreDistinct() {
        let target = "Simplified Chinese"
        let prompts = TranslationMode.allCases.map { $0.systemPrompt(target: target) }
        #expect(Set(prompts).count == TranslationMode.allCases.count)
    }
}
