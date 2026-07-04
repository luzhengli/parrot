import Foundation

enum E2EFailure: Error, CustomStringConvertible {
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
        throw E2EFailure.assertion(message)
    }
}

@main
struct HistoryClearConfirmationE2E {
    @MainActor
    static func main() throws {
        try verifyLocalHistoryBehavior()
        try verifyClearConfirmationSourceContract()

        print("history-clear-confirmation-e2e passed")
    }

    @MainActor
    private static func verifyLocalHistoryBehavior() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parrot-history-clear-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let suiteName = "parrot-history-clear-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let historyFile = tempDirectory.appendingPathComponent("translation-history.json")
        let store = TranslationHistoryStore(userDefaults: defaults, fileURL: historyFile, maxRecordCount: 10)

        store.addRecord(sourceText: "Original", translatedText: "Translated", sourceType: "Quick Text")
        try require(store.records.count == 1, "History should save local text records while enabled.")

        store.setHistoryEnabled(false)
        try require(store.records.count == 1, "Disabling history should preserve existing records until the user clears them.")

        store.addRecord(sourceText: "Ignored", translatedText: "Ignored", sourceType: "Quick Text")
        try require(store.records.count == 1, "Disabled history should not add new records.")

        store.clear()
        try require(store.records.isEmpty, "Confirmed clear should remove local text history records.")
        try require(FileManager.default.fileExists(atPath: historyFile.path), "Clearing history should keep using the local history file path.")
    }

    private static func verifyClearConfirmationSourceContract() throws {
        let source = try String(contentsOfFile: "Parrot/App/TranslationHistory.swift", encoding: .utf8)

        try require(
            source.contains("@State private var isShowingClearConfirmation = false"),
            "History view should keep explicit confirmation state."
        )
        try require(
            source.contains(".alert(\"Clear Translation History?\", isPresented: $isShowingClearConfirmation)"),
            "Clear History should present a confirmation alert before deleting records."
        )
        try require(
            source.contains("Button(\"Clear History\", role: .destructive)") && source.contains("store.clear()"),
            "The confirmed destructive action should clear local history."
        )
        try require(
            source.contains("Button(\"Cancel\", role: .cancel)"),
            "The confirmation alert should offer a cancel action that preserves records."
        )
        try require(
            source.contains("This deletes local text records only."),
            "The confirmation should explain the local text-only scope."
        )
        try require(
            source.contains("It does not delete API keys, provider settings, screenshots, or app preferences."),
            "The confirmation should name data that is not deleted."
        )
        try require(
            source.contains("isShowingClearConfirmation = true"),
            "The footer Clear History button should request confirmation instead of deleting immediately."
        )
        try require(
            source.contains("Local text-only translation history cleared."),
            "Confirmed clear should provide a short completion status."
        )
    }
}
