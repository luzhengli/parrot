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
struct AlwaysOnTopPreferencesE2E {
    static func main() throws {
        try verifyPreferenceIndependence()
        try verifySourceContract()

        print("always-on-top-preferences-e2e passed")
    }

    private static func verifyPreferenceIndependence() throws {
        let suiteName = "parrot-always-on-top-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let expectedKeys: [ParrotAlwaysOnTopSurface: String] = [
            .quickText: "quickText.alwaysOnTop",
            .screenshotTranslation: "screenshotTranslation.alwaysOnTop",
            .history: "history.alwaysOnTop",
            .settings: "settings.alwaysOnTop",
            .about: "about.alwaysOnTop"
        ]

        for surface in ParrotAlwaysOnTopSurface.allCases {
            try require(surface.storageKey == expectedKeys[surface], "Unexpected storage key for \(surface).")
            try require(!ParrotAlwaysOnTopPreferences.isEnabled(for: surface, userDefaults: defaults), "\(surface) should default to off.")
        }

        ParrotAlwaysOnTopPreferences.set(true, for: .quickText, userDefaults: defaults)
        try require(ParrotAlwaysOnTopPreferences.isEnabled(for: .quickText, userDefaults: defaults), "Quick Text should persist enabled.")
        try require(!ParrotAlwaysOnTopPreferences.isEnabled(for: .screenshotTranslation, userDefaults: defaults), "Quick Text should not change Screenshot.")
        try require(!ParrotAlwaysOnTopPreferences.isEnabled(for: .history, userDefaults: defaults), "Quick Text should not change History.")
        try require(!ParrotAlwaysOnTopPreferences.isEnabled(for: .settings, userDefaults: defaults), "Quick Text should not change Settings.")
        try require(!ParrotAlwaysOnTopPreferences.isEnabled(for: .about, userDefaults: defaults), "Quick Text should not change About.")

        ParrotAlwaysOnTopPreferences.set(true, for: .screenshotTranslation, userDefaults: defaults)
        ParrotAlwaysOnTopPreferences.set(true, for: .about, userDefaults: defaults)
        try require(ParrotAlwaysOnTopPreferences.isEnabled(for: .quickText, userDefaults: defaults), "Quick Text should remain enabled.")
        try require(ParrotAlwaysOnTopPreferences.isEnabled(for: .screenshotTranslation, userDefaults: defaults), "Screenshot should persist independently.")
        try require(ParrotAlwaysOnTopPreferences.isEnabled(for: .about, userDefaults: defaults), "About should persist independently.")
        try require(!ParrotAlwaysOnTopPreferences.isEnabled(for: .settings, userDefaults: defaults), "About should not change Settings.")

        ParrotAlwaysOnTopPreferences.set(false, for: .quickText, userDefaults: defaults)
        try require(!ParrotAlwaysOnTopPreferences.isEnabled(for: .quickText, userDefaults: defaults), "Quick Text should persist disabled.")
        try require(ParrotAlwaysOnTopPreferences.isEnabled(for: .screenshotTranslation, userDefaults: defaults), "Screenshot should remain enabled.")
        try require(ParrotAlwaysOnTopPreferences.isEnabled(for: .about, userDefaults: defaults), "About should remain enabled.")
    }

    private static func verifySourceContract() throws {
        let quickText = try String(contentsOfFile: "Parrot/App/QuickTextTranslationView.swift", encoding: .utf8)
        let screenshot = try String(contentsOfFile: "Parrot/App/ScreenshotSelectionController.swift", encoding: .utf8)
        let history = try String(contentsOfFile: "Parrot/App/TranslationHistory.swift", encoding: .utf8)
        let settings = try String(contentsOfFile: "Parrot/App/ProviderSettingsView.swift", encoding: .utf8)
        let appDelegate = try String(contentsOfFile: "Parrot/App/AppDelegate.swift", encoding: .utf8)

        try require(pinAppearsBeforeHistory(in: quickText, surface: ".quickText"), "Quick Text pin button should appear before History.")
        try require(pinAppearsBeforeHistory(in: screenshot, surface: ".screenshotTranslation"), "Screenshot pin button should appear before History.")
        try require(
            history.contains("ParrotWindowTitleBar(title: AppLocalization.string(\"window.history.title\"))"),
            "History should expose a localized title bar for its pin control."
        )
        try require(history.contains("surface: .history"), "History should use the history pin surface.")

        try require(settings.contains("surface: activeAlwaysOnTopSurface"), "Settings should bind the title-bar pin to the active section surface.")
        try require(settings.contains("section == .about ? .about : .settings"), "Settings About should use an independent About pin surface.")
        try require(appDelegate.contains("window?.level = isEnabled ? .floating : .normal"), "Always on Top should map to NSWindow.Level only.")
        try require(appDelegate.contains("alwaysOnTopSurface: alwaysOnTopSurface"), "Window presenters should restore the saved pin surface.")
        try require(appDelegate.contains("settingsAlwaysOnTopSurface(for section: ProviderSettingsView.Section)"), "Settings should resolve the active pin surface in AppDelegate.")

        try require(screenshot.contains("level = .screenSaver"), "Screenshot selection overlay should keep its temporary screen-saver level.")
        try require(!screenshot.contains("ParrotAlwaysOnTopButton(\n                    surface: .screenshotSelection"), "Screenshot selection overlay should not gain a persistent pin surface.")
    }

    private static func pinAppearsBeforeHistory(in source: String, surface: String) -> Bool {
        guard let pinRange = source.range(of: "surface: \(surface)"),
              let historyRange = source.range(of: "clock.arrow.circlepath", range: pinRange.upperBound..<source.endIndex)
        else {
            return false
        }

        return pinRange.lowerBound < historyRange.lowerBound
    }
}
