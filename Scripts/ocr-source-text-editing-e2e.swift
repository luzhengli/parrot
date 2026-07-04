import AppKit
import Foundation

enum OCRSourceTextEditingE2EFailure: Error, CustomStringConvertible {
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
        throw OCRSourceTextEditingE2EFailure.assertion(message)
    }
}

@main
struct OCRSourceTextEditingE2E {
    @MainActor
    static func main() throws {
        let recognizingStatus = ScreenshotPipelineStatus.recognizing
        try require(recognizingStatus.isRecognizing, "Initial screenshot status should support a recognizing phase.")
        try require(!recognizingStatus.isSuccess, "Recognizing OCR should not be treated as OCR success.")
        try require(recognizingStatus.recognizedText == nil, "Recognizing OCR should not expose recognized text yet.")
        try require(
            recognizingStatus.message.localizedCaseInsensitiveContains("not uploaded"),
            "Recognizing status should preserve screenshot upload privacy copy."
        )

        var sourceState = OCRSourceTextEditingState(recognizedText: "\nRaw OCR text\n")
        try require(sourceState.originalRecognizedText == "Raw OCR text", "Initial OCR text should be trimmed.")
        try require(sourceState.editedText == "Raw OCR text", "Editable source should default to the OCR text.")
        try require(sourceState.requestText == "Raw OCR text", "Initial provider request text should use OCR text.")
        try require(!sourceState.hasEditedText, "Initial OCR text should not be marked edited.")
        try require(sourceState.canRequestTranslation, "Non-empty OCR text should be translatable.")

        sourceState.updateEditedText("  Edited OCR text with corrected productName  ")
        try require(sourceState.hasEditedText, "Changing the source should mark the OCR text as edited.")
        try require(
            sourceState.requestText == "Edited OCR text with corrected productName",
            "Provider request text should use the edited source."
        )

        let client = OpenAICompatibleProviderClient(settings: .defaults, apiKey: "test-api-key")
        let preferences = TranslationLanguagePreferences(sourceLanguage: .english, targetLanguage: .chinese)
        let promptPreferences = TranslationPromptPreferences(
            isCustomPromptEnabled: true,
            customPromptTemplate: "Translate into {target_language}: {text}"
        )
        let prompt = try client.translationDebugPrompt(
            for: sourceState.requestText,
            preferences: preferences,
            promptPreferences: promptPreferences,
            glossaryEntries: []
        )
        try require(prompt.contains("Edited OCR text with corrected productName"), "Provider prompt should contain edited OCR text.")
        try require(!prompt.contains("Raw OCR text"), "Provider prompt should not contain stale OCR text after editing.")

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parrot-ocr-source-editing-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let suiteName = "parrot-ocr-source-editing-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw OCRSourceTextEditingE2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let historyFile = tempDirectory.appendingPathComponent("translation-history.json")
        let historyStore = TranslationHistoryStore(userDefaults: defaults, fileURL: historyFile, maxRecordCount: 5)
        historyStore.addRecord(
            sourceText: sourceState.requestText,
            translatedText: "已修正的译文",
            sourceType: "Screenshot"
        )

        try require(historyStore.records.count == 1, "Edited screenshot translation should save one history record.")
        try require(
            historyStore.records[0].sourceText == "Edited OCR text with corrected productName",
            "History should save the edited source text."
        )
        try require(
            historyStore.records[0].sourceText != sourceState.originalRecognizedText,
            "History should not save the original stale OCR text after editing."
        )

        let persistedHistory = try String(contentsOf: historyFile, encoding: .utf8)
        try require(persistedHistory.contains("Edited OCR text with corrected productName"), "Persisted history should include edited source text.")
        try require(!persistedHistory.contains("Raw OCR text"), "Persisted history should not include stale OCR text.")
        try require(!persistedHistory.contains("\"image\""), "History JSON should not contain a screenshot image field.")
        try require(!persistedHistory.contains("\"screenRect\""), "History JSON should not contain screenshot geometry.")
        try require(!persistedHistory.contains("base64"), "History JSON should not contain encoded screenshot data.")

        sourceState.updateEditedText("   \n  ")
        try require(!sourceState.canRequestTranslation, "Blank edited source text should not be translatable.")

        print("ocr-source-text-editing-e2e passed")
    }
}
