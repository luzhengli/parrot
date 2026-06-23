import Foundation

enum CustomTranslationPromptE2EFailure: Error, CustomStringConvertible {
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
        throw CustomTranslationPromptE2EFailure.assertion(message)
    }
}

@main
struct CustomTranslationPromptE2E {
    static func main() throws {
        let suiteName = "parrot-custom-translation-prompt-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw CustomTranslationPromptE2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(
            TranslationPromptPreferences.defaultPromptTemplate.contains("{target_language}"),
            "Default Prompt display should include target language variable."
        )
        try require(
            TranslationPromptPreferences.defaultPromptTemplate.contains("{text}"),
            "Default Prompt display should include text variable."
        )
        try require(
            TranslationPromptPreferences.validationMessage(for: "Translate to {target_language}") != nil,
            "Custom Prompt should require {text}."
        )
        try require(
            TranslationPromptPreferences.validationMessage(for: "Translate this text: {text}") != nil,
            "Custom Prompt should require {target_language}."
        )
        try require(
            TranslationPromptPreferences.validationMessage(for: "Translate to {target_language}: {text}") == nil,
            "Custom Prompt with required variables should validate."
        )

        let defaultPreferences = TranslationPromptPreferences.loadSaved(from: defaults)
        try require(!defaultPreferences.isCustomPromptEnabled, "Custom Prompt should be disabled by default.")
        try require(defaultPreferences.customPromptTemplate == TranslationPromptPreferences.defaultPromptTemplate, "Default custom template should mirror built-in Prompt display.")

        let invalidEnabledPreferences = TranslationPromptPreferences(
            isCustomPromptEnabled: true,
            customPromptTemplate: "Broken template without required variables"
        )
        try require(invalidEnabledPreferences.activeCustomTemplate == nil, "Invalid enabled custom Prompt should not become active.")
        do {
            try invalidEnabledPreferences.save(to: defaults)
            throw CustomTranslationPromptE2EFailure.assertion("Saving invalid custom Prompt should fail.")
        } catch let error as ProviderSettingsError {
            try require(error.localizedDescription.contains("{target_language}"), "Invalid custom Prompt save should explain missing required variables.")
        }

        let validTemplate = """
        CUSTOM PROMPT
        Source={source_language}
        Target={target_language}
        Style={style}
        Glossary={glossary}
        Text={text}
        """
        let validPreferences = TranslationPromptPreferences(isCustomPromptEnabled: true, customPromptTemplate: validTemplate)
        try validPreferences.save(to: defaults)
        try require(TranslationPromptPreferences.loadSaved(from: defaults) == validPreferences, "Valid custom Prompt should persist.")

        let client = OpenAICompatibleProviderClient(settings: .defaults, apiKey: "test-api-key")
        let languagePreferences = TranslationLanguagePreferences(sourceLanguage: .english, targetLanguage: .chinese)
        let customPrompt = try client.translationDebugPrompt(
            for: "Hello Parrot",
            preferences: languagePreferences,
            style: .professional,
            promptPreferences: validPreferences
        )
        try require(customPrompt.contains("CUSTOM PROMPT"), "Active custom Prompt should be used for translation.")
        try require(customPrompt.contains("Source=English"), "Custom Prompt should render source language.")
        try require(customPrompt.contains("Target=Simplified Chinese"), "Custom Prompt should render target language.")
        try require(customPrompt.contains("Style=Professional"), "Custom Prompt should render style.")
        try require(customPrompt.contains("Text=Hello Parrot"), "Custom Prompt should render source text.")
        try require(!customPrompt.contains("{text}"), "Rendered custom Prompt should not leave required variables unresolved.")

        let fallbackPrompt = try client.translationDebugPrompt(
            for: "Hello Parrot",
            preferences: languagePreferences,
            style: .professional,
            promptPreferences: invalidEnabledPreferences
        )
        try require(!fallbackPrompt.contains("Broken template"), "Invalid saved custom Prompt should fall back to built-in behavior.")
        try require(fallbackPrompt.contains("You are a professional translation assistant."), "Fallback Prompt should be the built-in Prompt.")
        try require(fallbackPrompt.contains("Translation style: Professional."), "Fallback Prompt should preserve selected style.")

        TranslationPromptPreferences.restoreDefault(to: defaults)
        try require(TranslationPromptPreferences.loadSaved(from: defaults) == .defaults, "Restore Default should clear saved custom Prompt settings.")

        let standardDefaults = UserDefaults.standard
        let existingStandardValue = standardDefaults.data(forKey: TranslationPromptPreferences.storageKey)
        defer {
            if let existingStandardValue {
                standardDefaults.set(existingStandardValue, forKey: TranslationPromptPreferences.storageKey)
            } else {
                standardDefaults.removeObject(forKey: TranslationPromptPreferences.storageKey)
            }
        }

        try validPreferences.save()
        let defaultLoadedPrompt = try client.translationDebugPrompt(
            for: "Bonjour",
            preferences: TranslationLanguagePreferences(sourceLanguage: .french, targetLanguage: .english),
            style: .natural
        )
        try require(defaultLoadedPrompt.contains("CUSTOM PROMPT"), "Translation calls should load the latest saved custom Prompt by default.")
        try require(defaultLoadedPrompt.contains("Target=English"), "Saved custom Prompt should affect the active translation direction.")

        print("custom-translation-prompt-e2e passed")
    }
}
