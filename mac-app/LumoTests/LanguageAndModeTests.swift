import Foundation
import NaturalLanguage
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

// MARK: - LanguageDetector.destination(for:target:fallback:)

@Suite("LanguageDetector.destination branch selection")
struct LanguageDetectorDestinationTests {
    @Test("Input already in the target flips to the fallback")
    func alreadyTargetFlips() {
        let result = LanguageDetector.destination(
            for: "This is English input and should flip to the fallback language.",
            target: "English",
            fallback: "Simplified Chinese"
        )
        #expect(result == "Simplified Chinese")
    }

    @Test("Input in any other language goes to the target")
    func otherLanguageGoesToTarget() {
        let result = LanguageDetector.destination(
            for: "这是中文输入内容，应当翻译成目标语言。",
            target: "English",
            fallback: "Simplified Chinese"
        )
        #expect(result == "English")
    }

    @Test("A third language still goes to the target, not the fallback")
    func thirdLanguageGoesToTarget() {
        let result = LanguageDetector.destination(
            for: "これは日本語の入力です。",
            target: "English",
            fallback: "Simplified Chinese"
        )
        #expect(result == "English")
    }

    @Test("Traditional Chinese input counts as already-in-target for Simplified Chinese")
    func chineseFamilyCountsAsTarget() {
        let result = LanguageDetector.destination(
            for: "這是繁體中文輸入，目標已是中文时应当掉头。",
            target: "Simplified Chinese",
            fallback: "English"
        )
        #expect(result == "English")
    }

    @Test("A non-English target routes by its own detection")
    func nonEnglishTarget() {
        let japanese = LanguageDetector.destination(
            for: "これは日本語の入力です。",
            target: "Japanese",
            fallback: "Simplified Chinese"
        )
        let english = LanguageDetector.destination(
            for: "This is English input.",
            target: "Japanese",
            fallback: "Simplified Chinese"
        )
        #expect(japanese == "Simplified Chinese")
        #expect(english == "Japanese")
    }

    @Test("An unmappable target never flips")
    func unmappableTargetNeverFlips() {
        // "Klingon" maps to no NLLanguage, so every input stays on target.
        let chinese = LanguageDetector.destination(
            for: "中文输入也无法检测目标语言。",
            target: "Klingon",
            fallback: "English"
        )
        let english = LanguageDetector.destination(
            for: "English input cannot detect Klingon either.",
            target: "Klingon",
            fallback: "English"
        )
        #expect(chinese == "Klingon")
        #expect(english == "Klingon")
    }

    @Test("An unmappable fallback is returned verbatim when flipping")
    func unmappableFallbackReturnedVerbatim() {
        let result = LanguageDetector.destination(
            for: "This is English input and should flip to the fallback label.",
            target: "English",
            fallback: "Klingon"
        )
        #expect(result == "Klingon")
    }
}

// MARK: - LanguageDetector.resolvedDestination

@Suite("LanguageDetector.resolvedDestination")
struct LanguageDetectorResolvedDestinationTests {
    @Test("A non-empty override wins over detection")
    func overrideWins() {
        let result = LanguageDetector.resolvedDestination(
            text: "这是中文。",
            target: "English",
            fallback: "Simplified Chinese",
            override: "Japanese"
        )
        #expect(result == "Japanese")
    }

    @Test("Blank override falls through to detection")
    func blankOverrideFallsThrough() {
        let result = LanguageDetector.resolvedDestination(
            text: "这是中文。",
            target: "English",
            fallback: "Simplified Chinese",
            override: "   "
        )
        #expect(result == "English")
    }

    @Test("Empty input prefills the default target")
    func emptyInputPrefillsTarget() {
        let result = LanguageDetector.resolvedDestination(
            text: "",
            target: "English",
            fallback: "Simplified Chinese",
            override: nil
        )
        #expect(result == "English")
    }
}

// MARK: - LanguageDetector.languageCode(for:)

@Suite("LanguageDetector.languageCode")
struct LanguageDetectorLanguageCodeTests {
    @Test("Preset names map to their NLLanguage", arguments: [
        ("English", NLLanguage.english),
        ("Simplified Chinese", NLLanguage.simplifiedChinese),
        ("Traditional Chinese", NLLanguage.traditionalChinese),
        ("Japanese", NLLanguage.japanese),
        ("Korean", NLLanguage.korean),
        ("French", NLLanguage.french),
        ("German", NLLanguage.german),
        ("Spanish", NLLanguage.spanish),
        ("Portuguese", NLLanguage.portuguese),
        ("Italian", NLLanguage.italian),
        ("Russian", NLLanguage.russian),
        ("Arabic", NLLanguage.arabic),
    ] as [(String, NLLanguage)])
    func presetMapping(name: String, language: NLLanguage) {
        #expect(LanguageDetector.languageCode(for: name) == language)
    }

    @Test("Raw NLLanguage codes typed into the custom field are accepted")
    func rawCodes() {
        #expect(LanguageDetector.languageCode(for: "en") == .english)
        #expect(LanguageDetector.languageCode(for: "zh-Hans") == .simplifiedChinese)
        #expect(LanguageDetector.languageCode(for: "ja") == .japanese)
    }

    @Test("Unknown names return nil")
    func unknownName() {
        #expect(LanguageDetector.languageCode(for: "Klingon") == nil)
        #expect(LanguageDetector.languageCode(for: "") == nil)
    }
}

// MARK: - LanguageDetector.isInLanguage(_:_:)

@Suite("LanguageDetector.isInLanguage")
struct LanguageDetectorIsInLanguageTests {
    @Test("Chinese text is in the Chinese language family")
    func chineseFamily() {
        #expect(LanguageDetector.isInLanguage("这是一段中文。", .simplifiedChinese))
        #expect(LanguageDetector.isInLanguage("這是繁體中文。", .simplifiedChinese))
        #expect(LanguageDetector.isInLanguage("這是繁體中文。", .traditionalChinese))
    }

    @Test("Non-Chinese text is not in the Chinese family")
    func notChineseFamily() {
        #expect(LanguageDetector.isInLanguage("This is English.", .simplifiedChinese) == false)
    }

    @Test("Text matches its own non-Chinese language")
    func nonChineseMatch() {
        #expect(LanguageDetector.isInLanguage("This is English text.", .english))
        #expect(LanguageDetector.isInLanguage("これは日本語です。", .japanese))
        #expect(LanguageDetector.isInLanguage("이것은 한국어입니다.", .korean))
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
