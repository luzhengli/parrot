import Foundation

enum TranslationStyleE2EFailure: Error, CustomStringConvertible {
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
        throw TranslationStyleE2EFailure.assertion(message)
    }
}

@main
struct TranslationStyleE2E {
    static func main() throws {
        let suiteName = "parrot-translation-style-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TranslationStyleE2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(TranslationStyle.loadSaved(from: defaults) == .accurate, "Style should default to Accurate.")

        TranslationStyle.professional.save(to: defaults)
        try require(TranslationStyle.loadSaved(from: defaults) == .professional, "Saved style should persist.")

        defaults.set("unknown-style", forKey: TranslationStyle.storageKey)
        try require(TranslationStyle.loadSaved(from: defaults) == .accurate, "Invalid saved style should fall back to Accurate.")

        let client = OpenAICompatibleProviderClient(settings: .defaults, apiKey: "test-api-key")
        let text = "Hello, Parrot"
        let preferences = TranslationLanguagePreferences(sourceLanguage: .english, targetLanguage: .chinese)

        let accuratePrompt = try client.translationDebugPrompt(for: text, preferences: preferences, style: .accurate)
        try require(accuratePrompt.contains("Translation style: Accurate."), "Accurate prompt should include the style name.")
        try require(accuratePrompt.contains(TranslationStyle.accurate.promptInstruction), "Accurate prompt should include the accurate instruction.")

        let naturalPrompt = try client.translationDebugPrompt(for: text, preferences: preferences, style: .natural)
        try require(naturalPrompt.contains("Translation style: Natural."), "Natural prompt should include the style name.")
        try require(naturalPrompt.contains(TranslationStyle.natural.promptInstruction), "Natural prompt should include the natural instruction.")

        let professionalPrompt = try client.translationDebugPrompt(for: text, preferences: preferences, style: .professional)
        try require(professionalPrompt.contains("Translation style: Professional."), "Professional prompt should include the style name.")
        try require(professionalPrompt.contains(TranslationStyle.professional.promptInstruction), "Professional prompt should include the professional instruction.")

        let concisePrompt = try client.translationDebugPrompt(for: text, preferences: preferences, style: .concise)
        try require(concisePrompt.contains("Translation style: Concise."), "Concise prompt should include the style name.")
        try require(concisePrompt.contains(TranslationStyle.concise.promptInstruction), "Concise prompt should include the concise instruction.")

        try require(accuratePrompt.contains("Source language: English."), "Style should not remove source language context.")
        try require(accuratePrompt.contains("Target language: Simplified Chinese."), "Style should not remove target language context.")
        try require(accuratePrompt.contains("Preserve paragraph structure."), "Style should preserve core translation requirements.")

        try require(accuratePrompt != concisePrompt, "Changing style should change the prompt for the same text and language pair.")

        let standardDefaults = UserDefaults.standard
        let existingStandardValue = standardDefaults.string(forKey: TranslationStyle.storageKey)
        defer {
            if let existingStandardValue {
                standardDefaults.set(existingStandardValue, forKey: TranslationStyle.storageKey)
            } else {
                standardDefaults.removeObject(forKey: TranslationStyle.storageKey)
            }
        }

        TranslationStyle.concise.save()
        let defaultLoadedPrompt = try client.translationDebugPrompt(for: text, preferences: preferences)
        try require(defaultLoadedPrompt.contains("Translation style: Concise."), "Translation calls should load the latest saved style by default.")

        TranslationStyle.professional.save()
        let retranslatedPrompt = try client.translationDebugPrompt(for: text, preferences: preferences)
        try require(retranslatedPrompt.contains("Translation style: Professional."), "Retranslating the same text should use the latest saved style.")
        try require(defaultLoadedPrompt != retranslatedPrompt, "Changing the saved style should affect retranslation without changing source text.")

        print("translation-style-e2e passed")
    }
}
