import AppKit
import Carbon
import SwiftUI

struct KeyboardShortcutDescriptor: Codable, Equatable, Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let quickTextDefault = KeyboardShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(cmdKey | shiftKey)
    )
    static let screenshotDefault = KeyboardShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_2),
        modifiers: UInt32(cmdKey | shiftKey)
    )
    static let openSettingsDefault = KeyboardShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_Comma),
        modifiers: UInt32(cmdKey | optionKey)
    )

    var displayString: String {
        guard let keyName = Self.keyName(for: keyCode) else {
            return "Unsupported key"
        }

        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Cmd")
        }
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("Ctrl")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Option")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift")
        }
        parts.append(keyName)
        return parts.joined(separator: "+")
    }

    var validationMessage: String? {
        guard Self.keyName(for: keyCode) != nil else {
            return "Press a supported letter, number, function, or punctuation key."
        }

        let requiredModifiers = UInt32(cmdKey | controlKey | optionKey)
        guard modifiers & requiredModifiers != 0 else {
            return "Use at least Cmd, Ctrl, or Option so the shortcut is global and intentional."
        }

        return nil
    }

    static func from(event: NSEvent) -> KeyboardShortcutDescriptor? {
        let carbonModifiers = carbonModifiers(from: event.modifierFlags)
        return KeyboardShortcutDescriptor(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers
        )
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        return modifiers
    }

    private static func keyName(for keyCode: UInt32) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_Space: return "Space"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return nil
        }
    }
}

struct ShortcutPreferences: Codable, Equatable {
    static let storageKey = "ShortcutPreferences"
    static let defaults = ShortcutPreferences(
        quickTextTranslation: .quickTextDefault,
        screenshotTranslation: .screenshotDefault,
        openSettings: .openSettingsDefault
    )

    var quickTextTranslation: KeyboardShortcutDescriptor
    var screenshotTranslation: KeyboardShortcutDescriptor
    var openSettings: KeyboardShortcutDescriptor

    private enum CodingKeys: String, CodingKey {
        case quickTextTranslation
        case screenshotTranslation
        case openSettings
    }

    init(
        quickTextTranslation: KeyboardShortcutDescriptor,
        screenshotTranslation: KeyboardShortcutDescriptor,
        openSettings: KeyboardShortcutDescriptor
    ) {
        self.quickTextTranslation = quickTextTranslation
        self.screenshotTranslation = screenshotTranslation
        self.openSettings = openSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quickTextTranslation = try container.decode(
            KeyboardShortcutDescriptor.self,
            forKey: .quickTextTranslation
        )
        screenshotTranslation = try container.decode(
            KeyboardShortcutDescriptor.self,
            forKey: .screenshotTranslation
        )
        openSettings = try container.decodeIfPresent(
            KeyboardShortcutDescriptor.self,
            forKey: .openSettings
        ) ?? .openSettingsDefault
    }

    subscript(action: GlobalShortcutAction) -> KeyboardShortcutDescriptor {
        get {
            switch action {
            case .quickTextTranslation:
                return quickTextTranslation
            case .screenshotTranslation:
                return screenshotTranslation
            case .openSettings:
                return openSettings
            }
        }
        set {
            switch action {
            case .quickTextTranslation:
                quickTextTranslation = newValue
            case .screenshotTranslation:
                screenshotTranslation = newValue
            case .openSettings:
                openSettings = newValue
            }
        }
    }

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> ShortcutPreferences {
        guard let data = userDefaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(ShortcutPreferences.self, from: data)
        else {
            return .defaults
        }

        return preferences
    }

    func validationMessages() -> [GlobalShortcutAction: String] {
        var messages: [GlobalShortcutAction: String] = [:]

        for action in GlobalShortcutAction.allCases {
            if let message = self[action].validationMessage {
                messages[action] = message
            }
        }

        for action in GlobalShortcutAction.allCases {
            let conflicts = GlobalShortcutAction.allCases.contains { otherAction in
                otherAction != action && self[otherAction] == self[action]
            }
            if conflicts {
                messages[action] = "This shortcut is already used by another Parrot action."
            }
        }

        return messages
    }

    func save(to userDefaults: UserDefaults = .standard) throws {
        guard validationMessages().isEmpty else {
            throw ShortcutSettingsError.invalidPreferences
        }

        let data = try JSONEncoder().encode(self)
        userDefaults.set(data, forKey: Self.storageKey)
    }
}

enum ShortcutSettingsError: Error {
    case invalidPreferences
}

extension GlobalShortcutAction {
    var title: String {
        switch self {
        case .quickTextTranslation:
            return "Quick Text Translation"
        case .screenshotTranslation:
            return "Screenshot Translation"
        case .openSettings:
            return "Open Settings"
        }
    }
}

final class ShortcutSettingsStore: ObservableObject {
    @Published var preferences: ShortcutPreferences
    @Published private(set) var statusMessage: String?
    @Published private(set) var isStatusError = false

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        preferences = ShortcutPreferences.loadSaved(from: userDefaults)
    }

    var validationMessages: [GlobalShortcutAction: String] {
        preferences.validationMessages()
    }

    var canSave: Bool {
        validationMessages.isEmpty
    }

    func resetToDefaults() {
        preferences = .defaults
        statusMessage = "Default shortcuts restored. Save to apply them."
        isStatusError = false
    }

    func save() -> Bool {
        do {
            try preferences.save(to: userDefaults)
            statusMessage = "Shortcuts saved and applied."
            isStatusError = false
            return true
        } catch {
            statusMessage = "Fix invalid or conflicting shortcuts before saving."
            isStatusError = true
            return false
        }
    }
}

struct StatusMessageView: View {
    let message: String
    let isError: Bool

    var body: some View {
        ParrotStatusBanner(
            kind: isError ? .warning : .success,
            message: message
        )
    }
}

struct ShortcutSettingsSection: View {
    @ObservedObject var store: ShortcutSettingsStore
    let onSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsRow(
                title: GlobalShortcutAction.quickTextTranslation.title,
                detail: "Open the lightweight text translation window.",
                action: .quickTextTranslation
            )

            settingsRow(
                title: GlobalShortcutAction.screenshotTranslation.title,
                detail: "Start screen region selection for OCR translation.",
                action: .screenshotTranslation
            )

            settingsRow(
                title: GlobalShortcutAction.openSettings.title,
                detail: "Open the unified Settings window.",
                action: .openSettings
            )

            if let statusMessage = store.statusMessage {
                StatusMessageView(
                    message: statusMessage,
                    isError: store.isStatusError
                )
            }

            HStack {
                Button("Restore Defaults") {
                    store.resetToDefaults()
                }

                Spacer()

                Button("Save Shortcuts") {
                    if store.save() {
                        onSaved()
                    }
                }
                .disabled(!store.canSave)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func settingsRow(
        title: String,
        detail: String,
        action: GlobalShortcutAction
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ShortcutRecorderControl(
                    shortcut: Binding(
                        get: { store.preferences[action] },
                        set: { store.preferences[action] = $0 }
                    )
                )
                .frame(width: 180, height: 32)
            }

            if let message = store.validationMessages[action] {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}

struct ShortcutRecorderControl: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcutDescriptor

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onShortcutChange = { descriptor in
            shortcut = descriptor
        }
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.shortcut = shortcut
    }
}

final class RecorderView: NSView {
    var onShortcutChange: ((KeyboardShortcutDescriptor) -> Void)?

    var shortcut: KeyboardShortcutDescriptor = .quickTextDefault {
        didSet {
            updateLabel()
        }
    }

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateLabel()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        updateLabel()
    }

    override func keyDown(with event: NSEvent) {
        guard let descriptor = KeyboardShortcutDescriptor.from(event: event) else {
            return
        }

        shortcut = descriptor
        onShortcutChange?(descriptor)
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updateLabel()
        return super.resignFirstResponder()
    }

    private func updateLabel() {
        label.stringValue = isRecording ? "Press shortcut..." : shortcut.displayString
        layer?.borderColor = (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
    }
}
