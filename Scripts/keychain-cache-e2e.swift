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
    private(set) var secretReadCount = 0
    private(set) var copyMatchingCount = 0
    private(set) var lastCopyMatchingHadAuthenticationContext = false
    private(set) var lastCopyMatchingDisallowedInteraction = false
    private(set) var lastCopyMatchingAuthenticationUIFails = false
    var requireAuthenticationForSecretReads = false

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
        copyMatchingCount += 1
        let context = query[kSecUseAuthenticationContext as String] as? LAContext
        lastCopyMatchingHadAuthenticationContext = context != nil
        lastCopyMatchingDisallowedInteraction = context?.interactionNotAllowed == true
        if let authenticationUI = query[kSecUseAuthenticationUI as String] {
            lastCopyMatchingAuthenticationUIFails = CFEqual(authenticationUI as CFTypeRef, kSecUseAuthenticationUIFail)
        } else {
            lastCopyMatchingAuthenticationUIFails = false
        }

        guard let key = key(from: query) else {
            return errSecParam
        }

        guard let data = storage[key] else {
            return errSecItemNotFound
        }

        if query[kSecReturnData as String] as? Bool == true {
            if requireAuthenticationForSecretReads {
                return lastCopyMatchingDisallowedInteraction && lastCopyMatchingAuthenticationUIFails
                    ? errSecInteractionNotAllowed
                    : errSecAuthFailed
            }
            secretReadCount += 1
            item = data as CFData
        } else if query[kSecReturnAttributes as String] as? Bool == true {
            item = [
                kSecAttrService as String: query[kSecAttrService as String] as? String ?? "",
                kSecAttrAccount as String: query[kSecAttrAccount as String] as? String ?? ""
            ] as CFDictionary
        }

        return errSecSuccess
    }

    func errorMessage(for status: OSStatus) -> String? {
        "Fake Keychain status \(status)"
    }

    func saveDirectly(_ apiKey: String, service: String, providerID: String) {
        storage["\(service)|openai-compatible-api-key-\(providerID)"] = Data(apiKey.utf8)
    }

    func deleteDirectly(service: String, providerID: String) {
        storage.removeValue(forKey: "\(service)|openai-compatible-api-key-\(providerID)")
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

@main
struct KeychainCacheE2E {
    static func main() {
        do {
            try run()
            print("keychain-cache-e2e passed")
        } catch {
            fputs("keychain-cache-e2e failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        let service = "parrot-keychain-cache-e2e-\(UUID().uuidString)"
        let providerID = "cache-test"
        let lockedProviderID = "locked-test"
        let suiteName = "parrot-keychain-cache-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            KeychainSecretStore.clearProcessCacheForTesting()
        }

        let fakeKeychain = FakeKeychainAccess()
        let store = KeychainSecretStore(service: service, userDefaults: defaults, keychainAccess: fakeKeychain)

        try require(!store.hasSavedAPIKeyRecord(providerID: providerID), "New isolated service should start without an API Key setup record.")
        let settingsStore = ProviderSettingsStore(userDefaults: defaults, keychain: store)
        try require(!settingsStore.hasSavedAPIKey, "Settings should use setup metadata instead of probing Keychain.")
        settingsStore.selectProvider(LLMProviderPreset.glm.id)
        settingsStore.saveSettings()
        try require(fakeKeychain.copyMatchingCount == 0, "Opening or saving Settings without an API Key input should not read Keychain.")

        let missingRead = try store.readAPIKey(providerID: providerID)
        try require(missingRead == nil, "Missing setup record should return an in-app missing API Key state.")
        try require(fakeKeychain.copyMatchingCount == 0, "Missing setup record should not touch Keychain at all.")

        fakeKeychain.saveDirectly("first-secret", service: service, providerID: providerID)
        let hiddenRead = try store.readAPIKey(providerID: providerID)
        try require(hiddenRead == nil, "An old Keychain item without a setup record should not be read during translation.")
        try require(fakeKeychain.copyMatchingCount == 0, "Old Keychain items without setup records should not trigger password prompts.")

        try store.saveAPIKey("first-secret", providerID: providerID)
        try require(store.hasSavedAPIKeyRecord(providerID: providerID), "Saving should record that this provider has an API Key.")
        let firstRead = try store.readAPIKey(providerID: providerID)
        try require(firstRead == "first-secret", "Read after save should use the process cache.")
        try require(fakeKeychain.secretReadCount == 0, "Read after save should not hit Keychain secret data.")

        fakeKeychain.deleteDirectly(service: service, providerID: providerID)
        let cachedRead = try store.readAPIKey(providerID: providerID)
        try require(cachedRead == "first-secret", "Second read should use the process cache.")
        try require(fakeKeychain.secretReadCount == 0, "Cached secret read should not hit the keychain again.")

        try store.deleteAPIKey(providerID: providerID)
        try require(!store.hasSavedAPIKeyRecord(providerID: providerID), "Deleting should clear the setup record.")
        let readAfterDelete = try store.readAPIKey(providerID: providerID)
        try require(readAfterDelete == nil, "Deleting should clear the process cache.")
        try require(fakeKeychain.secretReadCount == 0, "Missing record after delete should not read secret data.")

        try store.saveAPIKey("second-secret", providerID: providerID)
        fakeKeychain.deleteDirectly(service: service, providerID: providerID)
        let savedCacheRead = try store.readAPIKey(providerID: providerID)
        try require(savedCacheRead == "second-secret", "Saving should refresh the process cache.")
        try require(fakeKeychain.secretReadCount == 0, "Saved cache should avoid another keychain secret read.")

        defaults.set([], forKey: "SavedAPIKeyProviderIDs")
        let readsBeforeRecordClear = fakeKeychain.copyMatchingCount
        let readWithClearedRecordAndCachedSecret = try store.readAPIKey(providerID: providerID)
        try require(
            readWithClearedRecordAndCachedSecret == nil,
            "A cleared setup record should block translation even when a process-cached API Key exists."
        )
        try require(
            fakeKeychain.copyMatchingCount == readsBeforeRecordClear,
            "A cleared setup record should not touch Keychain while rejecting a cached API Key."
        )

        KeychainSecretStore.clearProcessCacheForTesting()
        try store.saveAPIKey("locked-secret", providerID: lockedProviderID)
        KeychainSecretStore.clearProcessCacheForTesting()
        fakeKeychain.requireAuthenticationForSecretReads = true
        do {
            _ = try store.readAPIKey(providerID: lockedProviderID)
            throw E2EFailure.assertion("Locked Keychain reads should fail in-app instead of prompting.")
        } catch ProviderSettingsError.apiKeyRequiresReentry {
            try require(
                fakeKeychain.lastCopyMatchingHadAuthenticationContext,
                "Secret reads should pass an LAContext for non-interactive Keychain reads."
            )
            try require(
                fakeKeychain.lastCopyMatchingAuthenticationUIFails,
                "Secret reads should explicitly fail instead of showing system Keychain authentication UI."
            )
        }
        try require(
            !store.hasSavedAPIKeyRecord(providerID: lockedProviderID),
            "A saved-key record that requires system Keychain UI should be cleared after the in-app re-entry error."
        )

        let readsBeforeClearedRecordRetry = fakeKeychain.copyMatchingCount
        let readAfterClearedRecord = try store.readAPIKey(providerID: lockedProviderID)
        try require(readAfterClearedRecord == nil, "After clearing an unsafe record, translation should see a missing API Key state.")
        try require(
            fakeKeychain.copyMatchingCount == readsBeforeClearedRecordRetry,
            "Retrying after an unsafe record is cleared should not touch Keychain or show another system prompt."
        )

    }
}
