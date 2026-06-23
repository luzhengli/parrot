import Foundation

enum TranslationLanguageControlsE2EFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message):
            return message
        }
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TranslationLanguageControlsE2EFailure.assertion(message)
    }
}

@main
struct TranslationLanguageControlsE2E {
    static func main() throws {
        let suiteName = "parrot-translation-language-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TranslationLanguageControlsE2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let defaultPreferences = TranslationLanguagePreferences.loadSaved(from: defaults)
        try require(defaultPreferences.sourceLanguage == .auto, "Source language should default to Auto.")
        try require(defaultPreferences.targetLanguage == .autoOpposite, "Target language should default to Auto Opposite.")
        try require(defaultPreferences.validationMessage == nil, "Default language preferences should be valid.")

        let chineseResolution = try TranslationLanguageResolver.resolve(
            text: "你好，Parrot",
            preferences: defaultPreferences
        )
        try require(chineseResolution.sourceLanguage == .chinese, "Chinese source text should be detected as Chinese.")
        try require(chineseResolution.targetLanguage == .english, "Chinese source text should default to English target.")

        let englishResolution = try TranslationLanguageResolver.resolve(
            text: "Hello, Parrot",
            preferences: defaultPreferences
        )
        try require(englishResolution.sourceLanguage == .english, "English source text should be detected as English.")
        try require(englishResolution.targetLanguage == .chinese, "English source text should default to Chinese target.")

        let explicitPreferences = TranslationLanguagePreferences(
            sourceLanguage: .japanese,
            targetLanguage: .spanish
        )
        explicitPreferences.save(to: defaults)
        let reloadedPreferences = TranslationLanguagePreferences.loadSaved(from: defaults)
        try require(reloadedPreferences == explicitPreferences, "Explicit language preferences should persist.")

        let client = OpenAICompatibleProviderClient(settings: .defaults, apiKey: "test-api-key")
        let explicitPrompt = try client.translationDebugPrompt(
            for: "こんにちは",
            preferences: explicitPreferences
        )
        try require(explicitPrompt.contains("Source language: Japanese."), "Prompt should include explicit source language.")
        try require(explicitPrompt.contains("Target language: Spanish."), "Prompt should include explicit target language.")

        let invalidPreferences = TranslationLanguagePreferences(
            sourceLanguage: .english,
            targetLanguage: .english
        )
        try require(invalidPreferences.validationMessage != nil, "Same explicit source and target should be invalid.")
        do {
            _ = try TranslationLanguageResolver.resolve(text: "Hello", preferences: invalidPreferences)
            throw TranslationLanguageControlsE2EFailure.assertion("Same explicit source and target should fail resolution.")
        } catch ProviderSettingsError.requestFailed(let message) {
            try require(message.contains("must be different"), "Invalid language error should explain the conflict.")
        }

        var autoToFrench = TranslationLanguagePreferences(sourceLanguage: .auto, targetLanguage: .french)
        autoToFrench.swapLanguages(recentDetectedSource: nil)
        try require(autoToFrench.sourceLanguage == .french, "Swapping Auto -> French should make French the source.")
        try require(autoToFrench.targetLanguage == .autoOpposite, "Swapping Auto -> French should restore Auto Opposite target.")

        var autoOppositeAfterEnglish = TranslationLanguagePreferences(sourceLanguage: .auto, targetLanguage: .autoOpposite)
        autoOppositeAfterEnglish.swapLanguages(recentDetectedSource: .english)
        try require(autoOppositeAfterEnglish.sourceLanguage == .chinese, "Swapping detected English should make Chinese the source.")
        try require(autoOppositeAfterEnglish.targetLanguage == .english, "Swapping detected English should make English the target.")

        let swappedPrompt = try client.translationDebugPrompt(
            for: "你好",
            preferences: autoOppositeAfterEnglish
        )
        try require(swappedPrompt.contains("Source language: Simplified Chinese."), "Swapped prompt should use Chinese source.")
        try require(swappedPrompt.contains("Target language: English."), "Swapped prompt should use English target.")

        print("translation-language-controls-e2e passed")
    }
}
