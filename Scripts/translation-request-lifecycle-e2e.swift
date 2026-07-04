import AppKit
import Foundation
import LocalAuthentication
import Security

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

private final class FakeKeychainAccess: KeychainAccessing {
    private var storage: [String: Data] = [:]

    func add(_ query: [String: Any]) -> OSStatus {
        guard let key = key(from: query),
              let data = query[kSecValueData as String] as? Data
        else {
            return errSecParam
        }

        storage[key] = data
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        guard let key = key(from: query) else {
            return errSecParam
        }

        return storage.removeValue(forKey: key) == nil ? errSecItemNotFound : errSecSuccess
    }

    func copyMatching(_ query: [String: Any], item: inout CFTypeRef?) -> OSStatus {
        guard let key = key(from: query),
              let data = storage[key]
        else {
            return errSecItemNotFound
        }

        item = data as CFData
        return errSecSuccess
    }

    func errorMessage(for status: OSStatus) -> String? {
        "Fake Keychain status \(status)"
    }

    private func key(from query: [String: Any]) -> String? {
        guard let service = query[kSecAttrService as String] as? String,
              let account = query[kSecAttrAccount as String] as? String
        else {
            return nil
        }

        return "\(service)|\(account)"
    }
}

private struct FakeStreamingPlan {
    var tokens: [String]
    var delayNanoseconds: UInt64 = 1_000_000
    var ignoreCancellation = false
    var failureMessage: String?
}

private final class FakeStreamingProvider: TranslationStreamingProviding {
    private let lock = NSLock()
    private var plans: [FakeStreamingPlan]
    private(set) var requestedTexts: [String] = []

    init(plans: [FakeStreamingPlan]) {
        self.plans = plans
    }

    func translateStreaming(
        _ text: String,
        preferences: TranslationLanguagePreferences,
        style: TranslationStyle,
        promptPreferences: TranslationPromptPreferences,
        glossaryEntries: [TranslationGlossaryEntry]?,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let plan = nextPlan()
        appendRequestedText(text)
        var finalText = ""

        if let failureMessage = plan.failureMessage, plan.tokens.isEmpty {
            throw ProviderSettingsError.requestFailed(failureMessage)
        }

        for token in plan.tokens {
            try? await Task.sleep(nanoseconds: plan.delayNanoseconds)
            if !plan.ignoreCancellation {
                try Task.checkCancellation()
            }
            if let failureMessage = plan.failureMessage {
                throw ProviderSettingsError.requestFailed(failureMessage)
            }
            finalText += token
            await onDelta(token)
        }

        if !plan.ignoreCancellation {
            try Task.checkCancellation()
        }

        return finalText
    }

    private func nextPlan() -> FakeStreamingPlan {
        lock.lock()
        defer { lock.unlock() }
        guard !plans.isEmpty else {
            return FakeStreamingPlan(tokens: ["fallback"])
        }
        return plans.removeFirst()
    }

    private func appendRequestedText(_ text: String) {
        lock.lock()
        requestedTexts.append(text)
        lock.unlock()
    }
}

@main
struct TranslationRequestLifecycleE2E {
    static func main() async {
        do {
            try await run()
            print("translation-request-lifecycle-e2e passed")
        } catch {
            fputs("translation-request-lifecycle-e2e failed: \(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    private static func run() async throws {
        let providerID = "lifecycle-e2e"
        let service = "translation-request-lifecycle-e2e-\(UUID().uuidString)"
        let suiteName = "translation-request-lifecycle-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            KeychainSecretStore.clearProcessCacheForTesting()
            UserDefaults.standard.removeObject(forKey: LLMProviderSettings.storageKey)
        }

        let settings = LLMProviderSettings(
            providerID: providerID,
            baseURLString: "https://api.example.com/v1",
            modelName: "fake-model"
        )
        let settingsData = try JSONEncoder().encode(settings)
        UserDefaults.standard.set(settingsData, forKey: LLMProviderSettings.storageKey)

        let fakeKeychainAccess = FakeKeychainAccess()
        let keychain = KeychainSecretStore(service: service, userDefaults: defaults, keychainAccess: fakeKeychainAccess)
        try keychain.saveAPIKey("test-key", providerID: providerID)

        try await verifyCancelBlocksLateCallbacks(keychain: keychain)
        try await verifyNewRequestWins(keychain: keychain)
        try await verifySegmentRetryAndHistoryGate(keychain: keychain)
        try await verifyLargeTextRequiresConfirmation(keychain: keychain)
    }

    @MainActor
    private static func verifyCancelBlocksLateCallbacks(keychain: KeychainSecretStore) async throws {
        var history: [(String, String, String)] = []
        let provider = FakeStreamingProvider(plans: [
            FakeStreamingPlan(tokens: ["late"], delayNanoseconds: 40_000_000, ignoreCancellation: true)
        ])
        let store = QuickTextTranslationStore(
            keychain: keychain,
            clientFactory: { _, _ in provider },
            historyRecorder: { history.append(($0, $1, $2)) }
        )

        store.sourceText = "cancel me"
        let task = store.startTranslation()
        try await Task.sleep(nanoseconds: 5_000_000)
        store.cancelTranslation(showStatus: false)
        await task?.value

        try require(store.translatedText.isEmpty, "Late tokens after cancel should not update the closed/current UI.")
        try require(history.isEmpty, "Canceled translation should not write history.")
    }

    @MainActor
    private static func verifyNewRequestWins(keychain: KeychainSecretStore) async throws {
        var history: [(String, String, String)] = []
        let provider = FakeStreamingProvider(plans: [
            FakeStreamingPlan(tokens: ["old"], delayNanoseconds: 50_000_000, ignoreCancellation: true),
            FakeStreamingPlan(tokens: ["new"], delayNanoseconds: 1_000_000)
        ])
        let store = QuickTextTranslationStore(
            keychain: keychain,
            clientFactory: { _, _ in provider },
            historyRecorder: { history.append(($0, $1, $2)) }
        )

        store.sourceText = "first"
        let oldTask = store.startTranslation()
        try await Task.sleep(nanoseconds: 5_000_000)
        store.sourceText = "second"
        let newTask = store.startTranslation()
        await oldTask?.value
        await newTask?.value

        try require(store.translatedText == "new", "A newer request should be the only UI result.")
        try require(history.count == 1, "Only the newer completed request should write history.")
        try require(history.first?.0 == "second", "History should record the newer request source text.")
    }

    @MainActor
    private static func verifySegmentRetryAndHistoryGate(keychain: KeychainSecretStore) async throws {
        var history: [(String, String, String)] = []
        let longText = (0..<5)
            .map { index in "Paragraph \(index) " + String(repeating: "segment text ", count: 100) }
            .joined(separator: "\n\n")
        guard case .segmented(let segments) = LongTextTranslationPlanner.plan(for: longText) else {
            throw E2EFailure.assertion("Long test text should enter segmented mode.")
        }

        let provider = FakeStreamingProvider(plans: [
            FakeStreamingPlan(tokens: ["first-segment"], delayNanoseconds: 1_000_000),
            FakeStreamingPlan(tokens: [], delayNanoseconds: 1_000_000, failureMessage: "planned segment failure")
        ] + Array(repeating: FakeStreamingPlan(tokens: ["retry-segment"], delayNanoseconds: 1_000_000), count: segments.count))

        let store = QuickTextTranslationStore(
            keychain: keychain,
            clientFactory: { _, _ in provider },
            historyRecorder: { history.append(($0, $1, $2)) }
        )

        store.sourceText = longText
        let failedTask = store.startTranslation()
        await failedTask?.value
        try require(store.translatedText.contains("first-segment"), "A failed segment should preserve completed segment output in the UI.")
        try require(history.isEmpty, "A partially failed segmented translation should not write success history.")

        let retryTask = store.startTranslation(retryFailedSegmentOnly: true)
        await retryTask?.value
        try require(!store.isStatusError, "Retrying a failed segment should clear the failed state after success.")
        try require(history.count == 1, "Segment retry success should write one final merged history record.")
        try require(history.first?.1.contains("retry-segment") == true, "Merged history should include retried segment output.")
    }

    @MainActor
    private static func verifyLargeTextRequiresConfirmation(keychain: KeychainSecretStore) async throws {
        var history: [(String, String, String)] = []
        let provider = FakeStreamingProvider(plans: [
            FakeStreamingPlan(tokens: ["should-not-run"], delayNanoseconds: 1_000_000)
        ])
        let store = QuickTextTranslationStore(
            keychain: keychain,
            clientFactory: { _, _ in provider },
            historyRecorder: { history.append(($0, $1, $2)) }
        )

        store.sourceText = String(repeating: "large text ", count: 900)
        let task = store.startTranslation()
        await task?.value

        try require(store.requiresLargeTextConfirmation, "Over-limit long text should require explicit confirmation before sending.")
        try require(store.statusMessage?.contains("characters across about") == true, "Large text confirmation should include character and segment counts.")
        try require(store.statusMessage?.contains("Translation runs sequentially") == true, "Large text confirmation should explain sequential translation.")
        try require(store.statusMessage?.contains("can be canceled") == true, "Large text confirmation should explain cancellation.")
        try require(store.statusMessage?.contains("failed segments can be retried") == true, "Large text confirmation should explain retry behavior.")
        try require(provider.requestedTexts.isEmpty, "Over-limit long text should not silently call the provider.")
        try require(history.isEmpty, "Unconfirmed long text should not write history.")

        let quickTextSource = try String(contentsOfFile: "Parrot/App/QuickTextTranslationView.swift", encoding: .utf8)
        try require(
            quickTextSource.contains("Shift+Enter inserts a new line"),
            "Quick Text header should include the Shift+Enter multiline hint."
        )
    }
}
