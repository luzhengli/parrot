import Carbon
import Foundation

enum CustomShortcutsE2EFailure: Error, CustomStringConvertible {
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
        throw CustomShortcutsE2EFailure.assertion(message)
    }
}

@main
struct CustomShortcutsE2E {
    static func main() throws {
        let suiteName = "parrot-shortcuts-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw CustomShortcutsE2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let loadedDefaults = ShortcutPreferences.loadSaved(from: defaults)
        try require(
            loadedDefaults[.quickTextTranslation].displayString == "Cmd+Shift+T",
            "Quick Text should default to Cmd+Shift+T."
        )
        try require(
            loadedDefaults[.screenshotTranslation].displayString == "Cmd+Shift+2",
            "Screenshot should default to Cmd+Shift+2."
        )
        try require(
            loadedDefaults.validationMessages().isEmpty,
            "Default shortcuts should be valid."
        )

        var custom = loadedDefaults
        custom[.quickTextTranslation] = KeyboardShortcutDescriptor(
            keyCode: UInt32(kVK_ANSI_Y),
            modifiers: UInt32(cmdKey | optionKey)
        )
        try custom.save(to: defaults)

        let reloadedCustom = ShortcutPreferences.loadSaved(from: defaults)
        try require(
            reloadedCustom[.quickTextTranslation].displayString == "Cmd+Option+Y",
            "Custom Quick Text shortcut should persist."
        )
        try require(
            reloadedCustom[.screenshotTranslation].displayString == "Cmd+Shift+2",
            "Unchanged Screenshot shortcut should remain persisted."
        )

        var conflicting = reloadedCustom
        conflicting[.screenshotTranslation] = conflicting[.quickTextTranslation]
        try require(
            conflicting.validationMessages()[.quickTextTranslation] != nil,
            "Conflicting Quick Text shortcut should be rejected."
        )
        try require(
            conflicting.validationMessages()[.screenshotTranslation] != nil,
            "Conflicting Screenshot shortcut should be rejected."
        )

        var invalid = reloadedCustom
        invalid[.quickTextTranslation] = KeyboardShortcutDescriptor(
            keyCode: UInt32(kVK_ANSI_Z),
            modifiers: UInt32(shiftKey)
        )
        try require(
            invalid.validationMessages()[.quickTextTranslation] != nil,
            "Shift-only shortcut should be rejected as invalid."
        )

        let store = ShortcutSettingsStore(userDefaults: defaults)
        try require(
            store.preferences[.quickTextTranslation].displayString == "Cmd+Option+Y",
            "ShortcutSettingsStore should load saved preferences."
        )
        store.resetToDefaults()
        try require(
            store.preferences[.quickTextTranslation].displayString == "Cmd+Shift+T",
            "Restore Defaults should reset Quick Text shortcut."
        )
        try require(
            store.preferences[.screenshotTranslation].displayString == "Cmd+Shift+2",
            "Restore Defaults should reset Screenshot shortcut."
        )

        print("custom-shortcuts-e2e passed")
    }
}

