import AppKit
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
struct TranslationHistoryE2E {
    @MainActor
    static func main() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parrot-history-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let suiteName = "parrot-history-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let historyFile = tempDirectory.appendingPathComponent("translation-history.json")
        let store = TranslationHistoryStore(userDefaults: defaults, fileURL: historyFile, maxRecordCount: 2)

        try require(store.isHistoryEnabled, "History should be enabled by default.")
        try require(store.records.isEmpty, "New isolated store should start empty.")

        store.addRecord(sourceText: "Hello", translatedText: "你好", sourceType: "Quick Text")
        try require(store.records.count == 1, "Successful translation should create one history record.")
        try require(FileManager.default.fileExists(atPath: historyFile.path), "History should persist to a local JSON file.")

        let reloadedStore = TranslationHistoryStore(userDefaults: defaults, fileURL: historyFile, maxRecordCount: 2)
        try require(reloadedStore.records.count == 1, "History should reload from disk.")
        try require(reloadedStore.records[0].sourceText == "Hello", "Reloaded source text should match.")
        try require(reloadedStore.records[0].translatedText == "你好", "Reloaded translation should match.")

        reloadedStore.copyTranslation(reloadedStore.records[0])
        try require(NSPasteboard.general.string(forType: .string) == "你好", "Copy Translation should write the translated text.")

        reloadedStore.setHistoryEnabled(false)
        reloadedStore.addRecord(sourceText: "Ignored", translatedText: "忽略", sourceType: "Quick Text")
        try require(reloadedStore.records.count == 1, "Disabled history should not save new records.")

        reloadedStore.setHistoryEnabled(true)
        reloadedStore.addRecord(sourceText: "World", translatedText: "世界", sourceType: "Quick Text")
        reloadedStore.addRecord(sourceText: "Screenshot text", translatedText: "截图文本", sourceType: "Screenshot")
        try require(reloadedStore.records.count == 2, "History should cap records at the configured max count.")
        try require(reloadedStore.records[0].sourceType == "Screenshot", "Newest record should appear first.")

        reloadedStore.clear()
        try require(reloadedStore.records.isEmpty, "Clear History should remove all records.")

        print("translation-history-e2e passed")
    }
}

