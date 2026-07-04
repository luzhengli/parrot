import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    static let `default`: AppLanguage = .zhHans

    var localeIdentifier: String {
        rawValue
    }

    var pickerTitleKey: String {
        switch self {
        case .zhHans:
            return "settings.language.option.zh_hans"
        case .english:
            return "settings.language.option.en"
        }
    }
}

enum AppLanguagePreference {
    static let storageKey = "AppLanguagePreference"

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> AppLanguage {
        guard let rawValue = userDefaults.string(forKey: storageKey),
              let language = AppLanguage(rawValue: rawValue)
        else {
            return .default
        }

        return language
    }

    static func save(_ language: AppLanguage, to userDefaults: UserDefaults = .standard) {
        userDefaults.set(language.rawValue, forKey: storageKey)
    }
}

enum AppLocalization {
    static let tableName = "Localizable"
    private static var cachedSessionLanguage: AppLanguage?

    static var sessionLanguage: AppLanguage {
        if let cachedSessionLanguage {
            return cachedSessionLanguage
        }

        let language = AppLanguagePreference.loadSaved()
        cachedSessionLanguage = language
        return language
    }

    static func resetSessionLanguageForTesting(_ language: AppLanguage? = nil) {
        cachedSessionLanguage = language
    }

    static func string(
        _ key: String,
        language: AppLanguage? = nil,
        resourceRoot: URL? = nil
    ) -> String {
        let requestedLanguage = language ?? sessionLanguage
        if let value = localizedString(key, language: requestedLanguage, resourceRoot: resourceRoot) {
            return value
        }

        if requestedLanguage != .default,
           let value = localizedString(key, language: .default, resourceRoot: resourceRoot) {
            return value
        }

        return key
    }

    static func format(
        _ key: String,
        language: AppLanguage? = nil,
        resourceRoot: URL? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let resolvedLanguage = language ?? sessionLanguage
        let format = string(key, language: resolvedLanguage, resourceRoot: resourceRoot)
        return String(
            format: format,
            locale: Locale(identifier: resolvedLanguage.localeIdentifier),
            arguments: arguments
        )
    }

    static func resourceKeys(
        for language: AppLanguage,
        resourceRoot: URL
    ) -> Set<String> {
        let stringsURL = resourceRoot
            .appendingPathComponent("\(language.rawValue).lproj", isDirectory: true)
            .appendingPathComponent("\(tableName).strings")
        guard let dictionary = NSDictionary(contentsOf: stringsURL) as? [String: String] else {
            return []
        }
        return Set(dictionary.keys)
    }

    private static func localizedString(
        _ key: String,
        language: AppLanguage,
        resourceRoot: URL?
    ) -> String? {
        let bundle: Bundle?
        if let resourceRoot {
            let path = resourceRoot
                .appendingPathComponent("\(language.rawValue).lproj", isDirectory: true)
                .path
            bundle = Bundle(path: path)
        } else if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj") {
            bundle = Bundle(path: path)
        } else if let path = commandLineResourcePath(for: language) {
            bundle = Bundle(path: path)
        } else {
            bundle = nil
        }

        guard let bundle else {
            return nil
        }

        let value = bundle.localizedString(forKey: key, value: nil, table: tableName)
        return value == key ? nil : value
    }

    private static func commandLineResourcePath(for language: AppLanguage) -> String? {
        let resourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Parrot/Resources", isDirectory: true)
            .appendingPathComponent("\(language.rawValue).lproj", isDirectory: true)
        return FileManager.default.fileExists(atPath: resourceURL.path) ? resourceURL.path : nil
    }
}
