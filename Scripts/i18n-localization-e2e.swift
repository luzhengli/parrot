import Foundation

enum I18NLocalizationE2EFailure: Error, CustomStringConvertible {
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
        throw I18NLocalizationE2EFailure.assertion(message)
    }
}

@main
struct I18NLocalizationE2E {
    @MainActor
    static func main() throws {
        do {
            try run()
            print("i18n-localization-e2e passed")
        } catch {
            fputs("i18n-localization-e2e failed: \(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    private static func run() throws {
        AppLocalization.resetSessionLanguageForTesting(nil)

        try verifyResourceCompleteness()
        try verifyLanguagePreferenceDefaults()
        try verifyLocalizedLookup()
        try verifyRestartRequiredSessionSemantics()
        try verifyTranslationLanguageIndependence()
        try verifyPreferenceAndFileIsolation()
        try verifyHardcodedUILiteralScan()
    }

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    private static var resourceRoot: URL {
        repositoryRoot.appendingPathComponent("Parrot/Resources", isDirectory: true)
    }

    private static var appSourceRoot: URL {
        repositoryRoot.appendingPathComponent("Parrot/App", isDirectory: true)
    }

    private static func verifyResourceCompleteness() throws {
        let zhKeys = AppLocalization.resourceKeys(for: .zhHans, resourceRoot: resourceRoot)
        let enKeys = AppLocalization.resourceKeys(for: .english, resourceRoot: resourceRoot)

        try require(!zhKeys.isEmpty, "Simplified Chinese Localizable.strings should be readable.")
        try require(!enKeys.isEmpty, "English Localizable.strings should be readable.")
        try require(zhKeys == enKeys, "zh-Hans and en localization resources should contain the same keys.")

        let requiredKeys: Set<String> = [
            "settings.section.general",
            "settings.language.title",
            "settings.language.description",
            "settings.language.restart_notice",
            "settings.language.option.zh_hans",
            "settings.language.option.en",
            "menu.quick_text",
            "menu.screenshot",
            "menu.history",
            "window.quick_text.title",
            "window.screenshot.title",
            "window.history.title",
            "window.settings.title",
            "settings.model.status.saved",
            "provider.error.missing_api_key",
            "history.clear.confirm.title",
            "shortcut.action.quick_text",
            "translation_style.accurate",
            "floating_position.screen_center",
            "provider_preset.custom.detail"
        ]
        let missingRequiredKeys = requiredKeys.subtracting(zhKeys)
        try require(missingRequiredKeys.isEmpty, "Required i18n keys are missing: \(missingRequiredKeys.sorted().joined(separator: ", ")).")

        let referencedKeys = try localizedKeysReferencedInAppSources()
        let missingReferencedKeys = referencedKeys.subtracting(zhKeys)
        try require(
            missingReferencedKeys.isEmpty,
            "AppLocalization source references must exist in both resources: \(missingReferencedKeys.sorted().joined(separator: ", "))."
        )
    }

    private static func verifyLanguagePreferenceDefaults() throws {
        let suiteName = "parrot-i18n-language-defaults-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw I18NLocalizationE2EFailure.assertion("Unable to create isolated language defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(AppLanguagePreference.loadSaved(from: defaults) == .zhHans, "Fresh installs should default UI language to zh-Hans.")

        defaults.set("fr-FR", forKey: AppLanguagePreference.storageKey)
        try require(AppLanguagePreference.loadSaved(from: defaults) == .zhHans, "Invalid saved UI language should fall back to zh-Hans.")

        AppLanguagePreference.save(.english, to: defaults)
        try require(AppLanguagePreference.loadSaved(from: defaults) == .english, "English UI language preference should persist.")
    }

    private static func verifyLocalizedLookup() throws {
        try require(
            AppLocalization.string("menu.settings", language: .zhHans, resourceRoot: resourceRoot) == "设置",
            "zh-Hans resource lookup should return Simplified Chinese UI copy."
        )
        try require(
            AppLocalization.string("menu.settings", language: .english, resourceRoot: resourceRoot) == "Settings",
            "English resource lookup should return English UI copy."
        )
        try require(
            AppLocalization.string("settings.language.restart_notice", language: .zhHans, resourceRoot: resourceRoot).contains("重启 Parrot"),
            "zh-Hans restart notice should tell the user to restart Parrot."
        )
        try require(
            AppLocalization.string("settings.language.restart_notice", language: .english, resourceRoot: resourceRoot).contains("Restart Parrot"),
            "English restart notice should tell the user to restart Parrot."
        )
        try require(
            AppLocalization.string("missing.i18n.key", language: .english, resourceRoot: resourceRoot) == "missing.i18n.key",
            "Missing keys should fall back to the key for visible test failures."
        )
    }

    private static func verifyRestartRequiredSessionSemantics() throws {
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: AppLanguagePreference.storageKey)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: AppLanguagePreference.storageKey)
            } else {
                defaults.removeObject(forKey: AppLanguagePreference.storageKey)
            }
            AppLocalization.resetSessionLanguageForTesting(nil)
        }

        defaults.removeObject(forKey: AppLanguagePreference.storageKey)
        AppLocalization.resetSessionLanguageForTesting(nil)
        try require(AppLocalization.sessionLanguage == .zhHans, "Active session should start in zh-Hans when no language is saved.")

        AppLanguagePreference.save(.english)
        try require(AppLocalization.sessionLanguage == .zhHans, "Saving language should not hot-switch the active UI session.")

        AppLocalization.resetSessionLanguageForTesting(nil)
        try require(AppLocalization.sessionLanguage == .english, "A new session should load the saved English preference.")
    }

    private static func verifyTranslationLanguageIndependence() throws {
        let suiteName = "parrot-i18n-translation-language-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw I18NLocalizationE2EFailure.assertion("Unable to create isolated translation language defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let explicitPreferences = TranslationLanguagePreferences(
            sourceLanguage: .japanese,
            targetLanguage: .spanish
        )
        explicitPreferences.save(to: defaults)
        AppLanguagePreference.save(.english, to: defaults)
        try require(
            TranslationLanguagePreferences.loadSaved(from: defaults) == explicitPreferences,
            "Changing app UI language should not alter translation source or target preferences."
        )

        let defaultPreferences = TranslationLanguagePreferences.defaults
        let chineseResolution = try TranslationLanguageResolver.resolve(text: "你好，Parrot", preferences: defaultPreferences)
        try require(chineseResolution.targetLanguage == .english, "Default Chinese text should still translate to English.")

        let englishResolution = try TranslationLanguageResolver.resolve(text: "Hello, Parrot", preferences: defaultPreferences)
        try require(englishResolution.targetLanguage == .chinese, "Default English text should still translate to Simplified Chinese.")
    }

    @MainActor
    private static func verifyPreferenceAndFileIsolation() throws {
        let suiteName = "parrot-i18n-isolation-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw I18NLocalizationE2EFailure.assertion("Unable to create isolated app preference defaults.")
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("parrot-i18n-isolation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let providerSettings = LLMProviderSettings(
            providerID: LLMProviderPreset.custom.id,
            baseURLString: "https://api.example.com/v1",
            modelName: "model-a"
        )
        defaults.set(try JSONEncoder().encode(providerSettings), forKey: LLMProviderSettings.storageKey)
        defaults.set(["custom"], forKey: "SavedAPIKeyProviderIDs")

        try ShortcutPreferences.defaults.save(to: defaults)
        TranslationStyle.professional.save(to: defaults)

        let languagePreferences = TranslationLanguagePreferences(sourceLanguage: .japanese, targetLanguage: .spanish)
        languagePreferences.save(to: defaults)

        let promptPreferences = TranslationPromptPreferences(
            isCustomPromptEnabled: true,
            customPromptTemplate: "Target={target_language}\nText={text}"
        )
        try promptPreferences.save(to: defaults)

        ParrotLaunchHubPreferences.setShowOnStartup(false, in: defaults)
        ParrotDockIconPreferences.setShowDockIcon(true, in: defaults)
        ParrotAlwaysOnTopPreferences.set(true, for: .settings, userDefaults: defaults)
        FloatingWindowPositionPreference.lastPosition.save(to: defaults)

        let historyURL = tempDirectory.appendingPathComponent("translation-history.json")
        let historyStore = TranslationHistoryStore(userDefaults: defaults, fileURL: historyURL, maxRecordCount: 10)
        historyStore.addRecord(sourceText: "Original", translatedText: "Translated", sourceType: "Quick Text")
        historyStore.setHistoryEnabled(false)
        let historyDataBefore = try Data(contentsOf: historyURL)

        let glossaryURL = tempDirectory.appendingPathComponent("terminology-glossary.json")
        let glossaryStore = TranslationGlossaryStore(fileURL: glossaryURL)
        let glossaryEntry = TranslationGlossaryEntry(
            sourceTerm: "Cue-Pro",
            targetTerm: "提示工程",
            targetLanguage: .chinese,
            context: "Product term",
            isEnabled: true
        )
        try require(glossaryStore.save(entry: glossaryEntry), "Glossary entry should save before language preference changes.")
        let glossaryDataBefore = try Data(contentsOf: glossaryURL)

        AppLanguagePreference.save(.english, to: defaults)

        try require(AppLanguagePreference.loadSaved(from: defaults) == .english, "App language should save to its own UserDefaults key.")
        try require(LLMProviderSettings.loadSaved(from: defaults) == providerSettings, "Provider settings should not reset when app language changes.")
        try require(defaults.stringArray(forKey: "SavedAPIKeyProviderIDs") == ["custom"], "API Key setup record should not reset when app language changes.")
        try require(ShortcutPreferences.loadSaved(from: defaults) == .defaults, "Shortcut preferences should not reset when app language changes.")
        try require(TranslationStyle.loadSaved(from: defaults) == .professional, "Translation style should not reset when app language changes.")
        try require(TranslationLanguagePreferences.loadSaved(from: defaults) == languagePreferences, "Translation language preferences should not reset when app language changes.")
        try require(TranslationPromptPreferences.loadSaved(from: defaults) == promptPreferences, "Prompt preferences should not reset when app language changes.")
        try require(!ParrotLaunchHubPreferences.load(from: defaults).showOnStartup, "Launch Hub startup preference should not reset when app language changes.")
        try require(ParrotDockIconPreferences.load(from: defaults).showDockIcon, "Dock icon preference should not reset when app language changes.")
        try require(ParrotAlwaysOnTopPreferences.isEnabled(for: .settings, userDefaults: defaults), "Window pinning preference should not reset when app language changes.")
        try require(FloatingWindowPositionPreference.loadSaved(from: defaults) == .lastPosition, "Floating window position preference should not reset when app language changes.")
        try require(defaults.bool(forKey: TranslationHistoryStore.enabledStorageKey) == false, "History enabled preference should not reset when app language changes.")
        let historyDataAfter = try Data(contentsOf: historyURL)
        let glossaryDataAfter = try Data(contentsOf: glossaryURL)
        try require(historyDataAfter == historyDataBefore, "History records file should not change when app language changes.")
        try require(glossaryDataAfter == glossaryDataBefore, "Glossary file should not change when app language changes.")
    }

    private static func verifyHardcodedUILiteralScan() throws {
        let findings = try hardcodedUILiteralFindings()
        try require(
            findings.isEmpty,
            "Hardcoded user-facing UI literals should use AppLocalization: \(findings.joined(separator: "; "))"
        )
    }

    private static func localizedKeysReferencedInAppSources() throws -> Set<String> {
        let regex = try NSRegularExpression(pattern: "AppLocalization\\.(?:string|format)\\(\\s*\"([^\"]+)\"")
        var keys = Set<String>()

        for sourceURL in try swiftSourceFiles(under: appSourceRoot) {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in regex.matches(in: source, range: nsRange) {
                guard let keyRange = Range(match.range(at: 1), in: source) else {
                    continue
                }
                keys.insert(String(source[keyRange]))
            }
        }

        return keys
    }

    private static func hardcodedUILiteralFindings() throws -> [String] {
        let patterns = try [
            "Text": NSRegularExpression(pattern: "Text\\(\"([^\"]*)\""),
            "TextField": NSRegularExpression(pattern: "TextField\\(\"([^\"]*)\""),
            "SecureField": NSRegularExpression(pattern: "SecureField\\(\"([^\"]*)\""),
            "Button": NSRegularExpression(pattern: "Button\\(\"([^\"]*)\""),
            "Label": NSRegularExpression(pattern: "Label\\(\"([^\"]*)\""),
            "Toggle": NSRegularExpression(pattern: "Toggle\\(\"([^\"]*)\""),
            "Picker": NSRegularExpression(pattern: "Picker\\(\"([^\"]*)\""),
            "LabeledContent": NSRegularExpression(pattern: "LabeledContent\\(\"([^\"]*)\""),
            "alert": NSRegularExpression(pattern: "\\.alert\\(\"([^\"]*)\""),
            "NSMenuItem": NSRegularExpression(pattern: "NSMenuItem\\(title: \"([^\"]*)\""),
            "window.title": NSRegularExpression(pattern: "window\\.title = \"([^\"]*)\""),
            "help": NSRegularExpression(pattern: "\\.help\\(\"([^\"]*)\""),
            "accessibilityLabel": NSRegularExpression(pattern: "accessibilityLabel\\(\"([^\"]*)\""),
            "navigationTitle": NSRegularExpression(pattern: "\\.navigationTitle\\(\"([^\"]*)\""),
            "toolTip": NSRegularExpression(pattern: "toolTip = \"([^\"]*)\""),
            "statusMessage": NSRegularExpression(pattern: "statusMessage\\s*=\\s*\"([^\"]*)\"")
        ]

        var findings: [String] = []
        for sourceURL in try swiftSourceFiles(under: appSourceRoot) {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
            for (name, regex) in patterns {
                for match in regex.matches(in: source, range: nsRange) {
                    guard let valueRange = Range(match.range(at: 1), in: source) else {
                        continue
                    }
                    let value = String(source[valueRange])
                    if isAllowedHardcodedLiteral(value) {
                        continue
                    }
                    let line = lineNumber(for: match.range.location, in: source)
                    findings.append("\(sourceURL.lastPathComponent):\(line) \(name)(\"\(value)\")")
                }
            }
        }
        return findings.sorted()
    }

    private static func isAllowedHardcodedLiteral(_ value: String) -> Bool {
        if value == "Parrot" {
            return true
        }
        if value.contains("\\(") {
            return true
        }
        if value.contains("screenRect") {
            return true
        }
        if value.range(of: "[A-Za-z]", options: .regularExpression) == nil {
            return true
        }
        return false
    }

    private static func swiftSourceFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append(url)
        }
        return files
    }

    private static func lineNumber(for utf16Offset: Int, in source: String) -> Int {
        let prefix = source.utf16.prefix(utf16Offset)
        return prefix.reduce(1) { line, codeUnit in
            codeUnit == 10 ? line + 1 : line
        }
    }
}
