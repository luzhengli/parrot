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
struct ProviderEndpointTimeoutE2E {
    static func main() async {
        do {
            try await run()
            print("provider-endpoint-timeout-e2e passed")
        } catch {
            fputs("provider-endpoint-timeout-e2e failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let rootURL = try ProviderEndpointNormalizer.chatCompletionsURL(from: "https://api.example.com")
        try require(rootURL.absoluteString == "https://api.example.com/chat/completions", "Root provider URL should normalize to chat completions.")

        let v1URL = try ProviderEndpointNormalizer.chatCompletionsURL(from: "https://api.example.com/v1/")
        try require(v1URL.absoluteString == "https://api.example.com/v1/chat/completions", "/v1 provider URL should normalize to chat completions.")

        let fullURL = try ProviderEndpointNormalizer.chatCompletionsURL(from: "https://api.example.com/v1/chat/completions")
        try require(fullURL.absoluteString == "https://api.example.com/v1/chat/completions", "Full chat completions URL should not be duplicated.")

        do {
            _ = try ProviderEndpointNormalizer.chatCompletionsURL(from: "http://api.example.com/v1")
            throw E2EFailure.assertion("Non-HTTPS provider URL should be rejected.")
        } catch ProviderSettingsError.invalidBaseURL {
        }

        let suiteName = "provider-timeout-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(
            ProviderTimeoutPreference.loadSaved(from: defaults).requestTimeoutSeconds == 25,
            "Default timeout should preserve the existing 25 second request behavior."
        )
        ProviderTimeoutPreference(requestTimeoutSeconds: 60).save(to: defaults)
        let savedTimeout = ProviderTimeoutPreference.loadSaved(from: defaults)
        try require(savedTimeout.urlRequestTimeout == 60, "Saved timeout should affect URLRequest timeout.")
        try require(savedTimeout.standardResourceTimeout == 65, "Standard resource timeout should scale from the saved timeout.")
        try require(savedTimeout.streamingResourceTimeout == 80, "Streaming resource timeout should scale from the saved timeout.")

        ProviderTimeoutPreference(requestTimeoutSeconds: 1_000).save(to: defaults)
        try require(
            ProviderTimeoutPreference.loadSaved(from: defaults).requestTimeoutSeconds == ProviderTimeoutPreference.maximumRequestTimeoutSeconds,
            "Timeout should be clamped to the maximum supported value."
        )

        let unsafeMessage = "HTTP 401 Authorization: Bearer sk-testsecret1234567890 token=abcdef1234567890 api_key=secret-key-1234567890"
        let safeMessage = ProviderErrorSanitizer.safeMessage(unsafeMessage, redactedSecrets: ["secret-key-1234567890"])
        try require(!safeMessage.contains("sk-testsecret"), "sk-style keys should be redacted.")
        try require(!safeMessage.contains("abcdef1234567890"), "token-like values should be redacted.")
        try require(!safeMessage.contains("secret-key-1234567890"), "explicit secrets should be redacted.")
        try require(safeMessage.contains("HTTP 401"), "HTTP status summary should be preserved.")

        try runRecoveryActionPresentationValidation()
        try runAboutDiagnosticsValidation()
        try runOnboardingStateValidation()
        try runLaunchStartupValidation()
        try runDockIconPreferenceValidation()
        try await runUpdateCheckValidation()
        try await runSettingsPersistenceValidation()
    }

    private static func runOnboardingStateValidation() throws {
        let suiteName = "provider-onboarding-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated onboarding defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(
            ParrotOnboardingState.load(from: defaults).status == .notStarted,
            "Fresh install should start with onboarding not started."
        )
        try require(
            ParrotOnboardingState.shouldPresentOnLaunch(providerConfigurationIsValid: true, userDefaults: defaults),
            "Fresh install with a valid provider should present onboarding."
        )
        try require(
            ParrotOnboardingState.shouldPresentOnLaunch(providerConfigurationIsValid: false, userDefaults: defaults),
            "Fresh install with invalid provider should present setup/onboarding."
        )

        let skipped = ParrotOnboardingState.markSkipped(in: defaults)
        try require(skipped.status == .skipped, "Skipping onboarding should persist skipped state.")
        try require(
            !ParrotOnboardingState.shouldPresentOnLaunch(providerConfigurationIsValid: true, userDefaults: defaults),
            "Skipped onboarding should not reopen automatically for the same valid-provider schema."
        )
        try require(
            ParrotOnboardingState.shouldPresentOnLaunch(providerConfigurationIsValid: false, userDefaults: defaults),
            "Invalid provider setup should override skipped onboarding state."
        )

        let completed = ParrotOnboardingState.markCompleted(in: defaults)
        try require(completed.status == .completed, "Completing onboarding should persist completed state.")
        try require(
            !ParrotOnboardingState.shouldPresentOnLaunch(providerConfigurationIsValid: true, userDefaults: defaults),
            "Completed onboarding should not reopen automatically for the same schema."
        )

        defaults.set(
            ParrotOnboardingStatus.completed.rawValue,
            forKey: ParrotOnboardingState.statusKey
        )
        defaults.set(
            ParrotOnboardingState.currentSchemaVersion - 1,
            forKey: ParrotOnboardingState.schemaVersionKey
        )
        try require(
            ParrotOnboardingState.shouldPresentOnLaunch(providerConfigurationIsValid: true, userDefaults: defaults),
            "Older onboarding schema should present onboarding again."
        )

        let reset = ParrotOnboardingState.reset(in: defaults)
        try require(reset.status == .notStarted, "Reset should restore not-started onboarding state.")
    }

    private static func runLaunchStartupValidation() throws {
        let suiteName = "provider-launch-startup-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated launch startup defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(
            ParrotLaunchHubPreferences.load(from: defaults).showOnStartup,
            "Launch Hub startup display should default to enabled."
        )
        try require(
            ParrotStartupPresentation.destination(providerConfigurationIsValid: false, userDefaults: defaults) == .setup,
            "Invalid provider setup should open Setup before Launch Hub."
        )
        try require(
            ParrotStartupPresentation.destination(providerConfigurationIsValid: true, userDefaults: defaults) == .setup,
            "Fresh valid-provider install should open onboarding before Launch Hub."
        )

        _ = ParrotOnboardingState.markSkipped(in: defaults)
        try require(
            ParrotStartupPresentation.destination(providerConfigurationIsValid: true, userDefaults: defaults) == .launchHub,
            "Skipped onboarding with valid setup should show Launch Hub by default."
        )

        ParrotLaunchHubPreferences.setShowOnStartup(false, in: defaults)
        try require(
            !ParrotLaunchHubPreferences.load(from: defaults).showOnStartup,
            "Launch Hub startup preference should persist disabled state."
        )
        try require(
            ParrotStartupPresentation.destination(providerConfigurationIsValid: true, userDefaults: defaults) == .none,
            "Disabled Launch Hub startup should stay quiet when setup is valid."
        )
        try require(
            ParrotStartupPresentation.destination(providerConfigurationIsValid: false, userDefaults: defaults) == .setup,
            "Invalid provider setup should override disabled Launch Hub startup."
        )

        ParrotLaunchHubPreferences.setShowOnStartup(true, in: defaults)
        _ = ParrotOnboardingState.markCompleted(in: defaults)
        try require(
            ParrotStartupPresentation.destination(providerConfigurationIsValid: true, userDefaults: defaults) == .launchHub,
            "Completed onboarding with valid setup should show Launch Hub when startup display is enabled."
        )

        defaults.set(
            ParrotOnboardingStatus.completed.rawValue,
            forKey: ParrotOnboardingState.statusKey
        )
        defaults.set(
            ParrotOnboardingState.currentSchemaVersion - 1,
            forKey: ParrotOnboardingState.schemaVersionKey
        )
        try require(
            ParrotStartupPresentation.destination(providerConfigurationIsValid: true, userDefaults: defaults) == .setup,
            "Older onboarding schema should reopen Setup before Launch Hub."
        )
    }

    private static func runDockIconPreferenceValidation() throws {
        let suiteName = "provider-dock-icon-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated Dock icon defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(
            !ParrotDockIconPreferences.load(from: defaults).showDockIcon,
            "Dock icon should default to hidden for menu-bar mode."
        )

        ParrotDockIconPreferences.setShowDockIcon(true, in: defaults)
        try require(
            ParrotDockIconPreferences.load(from: defaults).showDockIcon,
            "Dock icon preference should persist enabled state."
        )

        ParrotDockIconPreferences.setShowDockIcon(false, in: defaults)
        try require(
            !ParrotDockIconPreferences.load(from: defaults).showDockIcon,
            "Dock icon preference should persist disabled state."
        )

        let appDelegateSource = try String(contentsOfFile: "Parrot/App/AppDelegate.swift", encoding: .utf8)
        try require(
            appDelegateSource.contains("ParrotDockIconPreferences.load().showDockIcon ? .regular : .prohibited"),
            "Startup activation policy should use regular only when Dock icon is enabled."
        )
        try require(
            appDelegateSource.contains("ParrotDockIconPreferences.load().showDockIcon ? .regular : .accessory"),
            "Foreground window presentation should preserve Dock icon state."
        )
        try require(
            appDelegateSource.contains("NSApp.setActivationPolicy(isVisible ? .regular : .accessory)"),
            "Settings toggle should apply Dock visibility immediately."
        )

        let settingsSource = try String(contentsOfFile: "Parrot/App/ProviderSettingsView.swift", encoding: .utf8)
        try require(
            settingsSource.contains("Toggle(\"Show Dock icon\", isOn: dockIconBinding)"),
            "Settings Launch section should expose the Show Dock icon toggle."
        )
        try require(
            settingsSource.contains("Parrot appears in the Dock and App Switcher."),
            "Enabled Dock copy should mention Dock and App Switcher."
        )
        try require(
            settingsSource.contains("Closing windows keeps Parrot running; use Quit Parrot to exit."),
            "Enabled Dock copy should explain close-versus-quit behavior."
        )
        try require(
            settingsSource.contains("Parrot stays in menu-bar mode."),
            "Disabled Dock copy should explain menu-bar mode."
        )
        try require(
            settingsSource.contains("Launch Hub, the menu bar, or shortcuts"),
            "Disabled Dock copy should mention remaining entry points."
        )
    }

    @MainActor
    private static func runUpdateCheckValidation() async throws {
        let releaseJSON = """
        {
          "tag_name": "v0.2.0",
          "name": "Parrot 0.2.0",
          "html_url": "https://github.com/luzhengli/parrot/releases/tag/v0.2.0",
          "published_at": "2026-07-04T10:00:00Z",
          "body": "Fixes and release polish.\\nSecond line.\\nThird line.\\nFourth line.\\nFifth line should be omitted.",
          "prerelease": true,
          "assets": [
            {
              "name": "Parrot-0.2.0.dmg",
              "browser_download_url": "https://github.com/luzhengli/parrot/releases/download/v0.2.0/Parrot-0.2.0.dmg"
            },
            {
              "name": "SHA256SUMS.txt",
              "browser_download_url": "https://github.com/luzhengli/parrot/releases/download/v0.2.0/SHA256SUMS.txt"
            }
          ]
        }
        """
        let releaseData = Data(releaseJSON.utf8)
        let release = try ParrotUpdateChecker.parseLatestRelease(from: releaseData)
        try require(release.version == "0.2.0", "GitHub release tag should normalize to a SemVer version.")
        try require(release.isPrerelease, "Prerelease flag should be preserved.")
        try require(release.downloadURL.absoluteString.hasSuffix("Parrot-0.2.0.dmg"), "DMG asset should be selected for manual download.")
        try require(release.downloadAssetName == "Parrot-0.2.0.dmg", "DMG asset name should be retained for one-click downloads.")
        try require(release.checksumSummary?.contains("SHA256SUMS.txt") == true, "Checksum metadata should be detected when present.")
        try require(!release.summary.contains("Fifth line"), "Release summary should be bounded.")

        let updateStatus = ParrotUpdateChecker.status(
            currentVersion: "0.1.0",
            currentBuild: "1",
            latestRelease: release
        )
        guard case .updateAvailable(let availableRelease, let message) = updateStatus else {
            throw E2EFailure.assertion("Older current version should report update available.")
        }
        try require(availableRelease.version == "0.2.0", "Update status should include latest release info.")
        try require(message.contains("download the unsigned release asset"), "Unsigned RC update message should explain one-click download.")
        try require(message.contains("manual approval"), "Unsigned RC update message should not imply silent replacement.")

        guard case .upToDate = ParrotUpdateChecker.status(currentVersion: "0.2.0", currentBuild: "1", latestRelease: release) else {
            throw E2EFailure.assertion("Equal current/latest version should report up to date.")
        }
        guard case .upToDate(let newerMessage) = ParrotUpdateChecker.status(currentVersion: "0.3.0", currentBuild: "1", latestRelease: release) else {
            throw E2EFailure.assertion("Newer local version should not prompt downgrade.")
        }
        try require(newerMessage.contains("newer than"), "Newer local version should explain that downgrade is not recommended.")

        let checker = ParrotUpdateChecker { request in
            try require(request.url == ParrotAboutInfo.latestReleaseAPIURL, "Update checker should call the GitHub latest release API.")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (releaseData, response)
        }
        await checker.checkForUpdates(currentVersion: "0.1.0", currentBuild: "1")
        guard case .updateAvailable = checker.status else {
            throw E2EFailure.assertion("Fake successful update feed should report update available.")
        }

        let invalidChecker = ParrotUpdateChecker { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data("{}".utf8), response)
        }
        await invalidChecker.checkForUpdates(currentVersion: "0.1.0", currentBuild: "1")
        guard case .unableToCheck(let invalidMessage) = invalidChecker.status else {
            throw E2EFailure.assertion("Invalid update feed should report unable to check.")
        }
        try require(invalidMessage.contains("Unable to check"), "Invalid feed failure should be user understandable.")

        let missingFeedChecker = ParrotUpdateChecker { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(#"{"message":"Not Found"}"#.utf8), response)
        }
        await missingFeedChecker.checkForUpdates(currentVersion: "0.1.0", currentBuild: "1")
        guard case .unableToCheck(let missingFeedMessage) = missingFeedChecker.status else {
            throw E2EFailure.assertion("Missing GitHub release feed should report unable to check.")
        }
        try require(
            missingFeedMessage.contains("release feed was not found"),
            "404 checks should explain that the configured public release feed is missing."
        )

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("parrot-update-download-e2e-\(UUID().uuidString)", isDirectory: true)
        let downloadsDirectory = temporaryRoot.appendingPathComponent("Downloads", isDirectory: true)
        let fakeDownloadedFile = temporaryRoot.appendingPathComponent("Parrot-0.2.0-source.dmg")
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        try Data("fake dmg".utf8).write(to: fakeDownloadedFile)
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }

        let downloader = ParrotUpdateDownloader(
            downloadLoader: { request in
                try require(request.url == release.downloadURL, "Update downloader should request the selected release asset.")
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (fakeDownloadedFile, response)
            },
            downloadsDirectoryProvider: {
                downloadsDirectory
            }
        )
        let savedURL = await downloader.download(release)
        try require(savedURL?.lastPathComponent == "Parrot-0.2.0.dmg", "One-click update download should save the release asset name.")
        try require(
            FileManager.default.fileExists(atPath: savedURL?.path ?? ""),
            "One-click update download should move the asset into Downloads."
        )
        guard case .downloaded(let downloadedName, let downloadedURL) = downloader.status else {
            throw E2EFailure.assertion("Successful one-click update download should report downloaded status.")
        }
        try require(downloadedName == "Parrot-0.2.0.dmg", "Downloaded status should include the asset name.")
        try require(downloadedURL == savedURL, "Downloaded status should include the saved file URL.")
    }

    private static func runAboutDiagnosticsValidation() throws {
        let sensitiveSettings = LLMProviderSettings(
            providerID: "custom",
            baseURLString: "https://secret-provider.example.com/v1",
            modelName: "secret-model-name"
        )
        let diagnostics = ParrotDiagnosticsSummary.current(
            settings: sensitiveSettings,
            screenRecordingPermissionGranted: false
        )
        let text = diagnostics.text

        try require(text.contains("Parrot Diagnostics"), "Diagnostics summary should have a clear title.")
        try require(text.contains("Provider Preset ID: custom"), "Diagnostics summary should include provider preset id.")
        try require(text.contains("Release Channel: Unsigned RC"), "Diagnostics summary should include unsigned RC release channel.")
        try require(text.contains("Screen Recording Permission: not granted"), "Diagnostics summary should include permission status.")
        try require(text.contains("Feature Flags:"), "Diagnostics summary should include feature flags.")
        try require(!text.contains("secret-provider"), "Diagnostics summary must not include provider endpoint host.")
        try require(!text.contains("secret-model-name"), "Diagnostics summary must not include model names.")
        try require(!text.contains("sk-testsecret"), "Diagnostics summary must not include API-key-like text.")
        try require(!text.contains("Bearer "), "Diagnostics summary must not include bearer tokens.")
        try require(!text.localizedCaseInsensitiveContains("source text"), "Diagnostics summary must not include user source text.")
        try require(!text.localizedCaseInsensitiveContains("provider response"), "Diagnostics summary must not include provider responses.")
        try require(!text.localizedCaseInsensitiveContains("history content"), "Diagnostics summary must not include history content.")
        try require(!text.localizedCaseInsensitiveContains("screenshot image"), "Diagnostics summary must not include screenshots.")
    }

    private static func runRecoveryActionPresentationValidation() throws {
        try require(
            UserFacingErrorPresentation(error: ProviderSettingsError.missingAPIKey).recoveryAction == .openSetup,
            "Missing API Key should route users to Setup."
        )
        try require(
            UserFacingErrorPresentation(error: ProviderSettingsError.apiKeyRequiresReentry).recoveryAction == .openSetup,
            "API Key re-entry should route users to Setup."
        )
        try require(
            UserFacingErrorPresentation(error: ProviderSettingsError.invalidBaseURL).recoveryAction == .openModelSettings,
            "Invalid Base URL should route users to Model settings."
        )
        try require(
            UserFacingErrorPresentation(error: ProviderSettingsError.missingModel).recoveryAction == .openModelSettings,
            "Missing model should route users to Model settings."
        )
        try require(
            UserFacingErrorPresentation(error: ProviderSettingsError.unexpectedResponse).recoveryAction == .openModelSettings,
            "Unsupported provider responses should route users to Model settings."
        )
        try require(
            UserFacingErrorPresentation(error: ProviderSettingsError.requestFailed("Network request failed: offline")).recoveryAction == .retry,
            "Network failures should keep users in the translation window with Retry."
        )
        try require(
            UserFacingErrorPresentation(error: ProviderSettingsError.requestFailed("The request timed out after 25 seconds.")).recoveryAction == .retry,
            "Timeout failures should keep users in the translation window with Retry."
        )

        let authenticationPresentation = UserFacingErrorPresentation(
            error: ProviderSettingsError.authenticationFailed("Bearer sk-testsecret1234567890")
        )
        try require(authenticationPresentation.recoveryAction == .openModelSettings, "Authentication failures should route users to Model settings.")
        try require(!authenticationPresentation.message.contains("sk-testsecret"), "Authentication error UI should redact API-key-like text.")
    }

    private static func runSettingsPersistenceValidation() async throws {
        let suiteName = "provider-settings-save-validation-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated provider settings defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = ProviderSettingsStore(
            userDefaults: defaults,
            keychain: KeychainSecretStore(userDefaults: defaults)
        )

        store.selectProvider(LLMProviderPreset.custom.id)
        store.baseURLString = "http://api.example.com/v1"
        store.modelName = "model-a"
        store.saveSettings()
        try require(store.isStatusError, "Non-HTTPS Save should show an error.")
        try require(!(store.statusMessage ?? "").contains("Settings saved"), "Non-HTTPS Save should not show success.")
        try require(loadPersistedSettings(from: defaults) == nil, "Non-HTTPS Save should not persist provider settings.")

        store.baseURLString = "https://api.example.com/v1"
        store.modelName = "   "
        store.saveSettings()
        try require(store.isStatusError, "Empty-model Save should show an error.")
        try require(!(store.statusMessage ?? "").contains("Settings saved"), "Empty-model Save should not show success.")
        try require(loadPersistedSettings(from: defaults) == nil, "Empty-model Save should not persist provider settings.")

        for baseURL in [
            "https://api.example.com",
            "https://api.example.com/v1",
            "https://api.example.com/v1/chat/completions"
        ] {
            defaults.removeObject(forKey: LLMProviderSettings.storageKey)
            store.baseURLString = baseURL
            store.modelName = "model-a"
            store.saveSettings()
            try require(!store.isStatusError, "Valid Save should succeed for \(baseURL).")
            try require((store.statusMessage ?? "").contains("Settings saved"), "Valid Save should show success for \(baseURL).")
            let savedSettings = try requirePersistedSettings(from: defaults)
            try require(savedSettings.baseURLString == baseURL, "Valid Save should persist the trimmed Base URL for \(baseURL).")
            try require(savedSettings.modelName == "model-a", "Valid Save should persist the model for \(baseURL).")
        }

        let lastGoodSettings = try requirePersistedSettings(from: defaults)
        store.baseURLString = "http://api.example.com/v1"
        store.modelName = "model-b"
        await store.testConnection()
        try require(store.isStatusError, "Non-HTTPS Test Connection should show an error.")
        try require(!(store.statusMessage ?? "").contains("Connection test succeeded"), "Invalid Test Connection should not show success.")
        let settingsAfterInvalidURLTest = try requirePersistedSettings(from: defaults)
        try require(settingsAfterInvalidURLTest == lastGoodSettings, "Invalid Test Connection should not overwrite saved settings.")

        store.baseURLString = "https://api.example.com/v1"
        store.modelName = " "
        await store.testConnection()
        try require(store.isStatusError, "Empty-model Test Connection should show an error.")
        let settingsAfterEmptyModelTest = try requirePersistedSettings(from: defaults)
        try require(settingsAfterEmptyModelTest == lastGoodSettings, "Empty-model Test Connection should not overwrite saved settings.")
    }

    private static func loadPersistedSettings(from defaults: UserDefaults) -> LLMProviderSettings? {
        guard let data = defaults.data(forKey: LLMProviderSettings.storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(LLMProviderSettings.self, from: data)
    }

    private static func requirePersistedSettings(from defaults: UserDefaults) throws -> LLMProviderSettings {
        guard let settings = loadPersistedSettings(from: defaults) else {
            throw E2EFailure.assertion("Expected provider settings to be persisted.")
        }
        return settings
    }
}
