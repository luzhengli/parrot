import Foundation

enum TerminologyGlossaryE2EFailure: Error, CustomStringConvertible {
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
        throw TerminologyGlossaryE2EFailure.assertion(message)
    }
}

@main
struct TerminologyGlossaryE2E {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parrot-terminology-glossary-e2e-\(UUID().uuidString)", isDirectory: true)
        let glossaryURL = directory.appendingPathComponent("terminology-glossary.json")
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = TranslationGlossaryStore(fileURL: glossaryURL)
        try require(store.entries.isEmpty, "A new glossary store should start empty.")

        let cueEntry = TranslationGlossaryEntry(
            sourceTerm: "Cue-Pro",
            targetTerm: "提示工程",
            targetLanguage: .chinese,
            context: "Product name",
            isEnabled: true
        )
        try require(store.save(entry: cueEntry), "A valid glossary entry should be saved.")
        try require(store.entries.count == 1, "Saved glossary entry should appear in the store.")

        let duplicateEntry = TranslationGlossaryEntry(
            sourceTerm: " cue-pro ",
            targetTerm: "重复项",
            targetLanguage: .chinese
        )
        try require(!store.save(entry: duplicateEntry), "Duplicate source term for the same target language should be rejected.")
        try require(store.isStatusError, "Duplicate rejection should surface an error status.")

        let englishEntry = TranslationGlossaryEntry(
            sourceTerm: "时间线",
            targetTerm: "timeline",
            targetLanguage: .english,
            context: "UI label",
            isEnabled: true
        )
        try require(store.save(entry: englishEntry), "Same source text can be saved for a different target language.")

        let disabledEntry = TranslationGlossaryEntry(
            sourceTerm: "private draft",
            targetTerm: "不应发送",
            targetLanguage: .chinese,
            isEnabled: false
        )
        try require(store.save(entry: disabledEntry), "Disabled glossary entries should still be storable.")

        let anyTargetEntry = TranslationGlossaryEntry(
            sourceTerm: "Parrot",
            targetTerm: "Parrot",
            targetLanguage: nil,
            context: "Keep product name",
            isEnabled: true
        )
        try require(store.save(entry: anyTargetEntry), "Any-target glossary entry should be storable.")

        let reloadedEntries = TranslationGlossaryStore.loadEntries(from: glossaryURL)
        try require(reloadedEntries.count == 4, "Glossary entries should persist to local JSON.")
        let glossaryJSON = String(data: try Data(contentsOf: glossaryURL), encoding: .utf8) ?? ""
        try require(
            glossaryJSON.contains("Cue-Pro"),
            "Local glossary JSON should contain saved terms."
        )
        try require(
            !glossaryJSON.contains("apiKey"),
            "Glossary JSON should not contain API key fields."
        )

        let client = OpenAICompatibleProviderClient(settings: .defaults, apiKey: "test-api-key")
        let chinesePrompt = try client.translationDebugPrompt(
            for: "Please translate Cue-Pro for Parrot, but not the private draft phrase.",
            preferences: TranslationLanguagePreferences(sourceLanguage: .english, targetLanguage: .chinese),
            style: .professional,
            glossaryEntries: store.entries
        )
        try require(chinesePrompt.contains("Cue-Pro -> 提示工程"), "Matched target-language glossary entry should be injected.")
        try require(chinesePrompt.contains("Parrot -> Parrot"), "Matched any-target glossary entry should be injected.")
        try require(!chinesePrompt.contains("时间线 -> timeline"), "Unmatched source term should not be injected.")
        try require(!chinesePrompt.contains("private draft -> 不应发送"), "Disabled glossary entry should not be injected.")

        let unmatchedPrompt = try client.translationDebugPrompt(
            for: "No saved terms appear here.",
            preferences: TranslationLanguagePreferences(sourceLanguage: .english, targetLanguage: .chinese),
            glossaryEntries: store.entries
        )
        try require(unmatchedPrompt.contains(TranslationGlossary.emptyPromptText), "Unmatched text should send the empty glossary marker only.")
        try require(!unmatchedPrompt.contains("Cue-Pro -> 提示工程"), "Unmatched glossary terms should not be sent.")

        let customPreferences = TranslationPromptPreferences(
            isCustomPromptEnabled: true,
            customPromptTemplate: "Target={target_language}\nGlossary={glossary}\nText={text}"
        )
        let customPrompt = try client.translationDebugPrompt(
            for: "Cue-Pro belongs to Parrot.",
            preferences: TranslationLanguagePreferences(sourceLanguage: .english, targetLanguage: .chinese),
            promptPreferences: customPreferences,
            glossaryEntries: store.entries
        )
        try require(customPrompt.contains("Cue-Pro -> 提示工程"), "Custom Prompt should receive matched glossary text.")
        try require(!customPrompt.contains("{glossary}"), "Custom Prompt should render the glossary variable.")

        if let firstEntry = store.entries.first(where: { $0.sourceTerm == "Parrot" }) {
            store.setEnabled(firstEntry, isEnabled: false)
        }
        let afterDisablePrompt = try client.translationDebugPrompt(
            for: "Parrot",
            preferences: TranslationLanguagePreferences(sourceLanguage: .english, targetLanguage: .chinese),
            glossaryEntries: store.entries
        )
        try require(!afterDisablePrompt.contains("Parrot -> Parrot"), "Disabled entries should stop being injected.")

        if var entryToEdit = store.entries.first(where: { $0.sourceTerm == "Cue-Pro" }) {
            let editingID = entryToEdit.id
            entryToEdit.targetTerm = "Cue-Pro"
            try require(store.save(entry: entryToEdit, editingID: editingID), "Editing an existing glossary entry should update it.")
        }
        try require(
            store.entries.contains { $0.sourceTerm == "Cue-Pro" && $0.targetTerm == "Cue-Pro" },
            "Edited glossary entry should be stored in memory."
        )

        if let entryToDelete = store.entries.first(where: { $0.sourceTerm == "时间线" }) {
            store.delete(entryToDelete)
        }
        try require(
            !store.entries.contains { $0.sourceTerm == "时间线" },
            "Deleting a glossary entry should remove it from the store."
        )

        print("terminology-glossary-e2e passed")
    }
}
