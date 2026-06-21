import Carbon
import Foundation

enum GlobalShortcutAction: UInt32, CaseIterable {
    case quickTextTranslation = 1
    case screenshotTranslation = 2
}

enum GlobalShortcutRegistrationError: Error, CustomStringConvertible {
    case eventHandlerInstallFailed(status: OSStatus)
    case hotKeyRegistrationFailed(action: GlobalShortcutAction, status: OSStatus)

    var description: String {
        switch self {
        case .eventHandlerInstallFailed(let status):
            return "Unable to install the global shortcut event handler. Carbon returned status \(status)."
        case .hotKeyRegistrationFailed(let action, let status):
            let shortcut = ShortcutPreferences.loadSaved()[action].displayString
            return "Unable to register \(action.title) shortcut \(shortcut). It may already be used by another app or system shortcut. Carbon returned status \(status)."
        }
    }
}

final class GlobalShortcutManager {
    typealias Handler = (GlobalShortcutAction) -> Void

    private static let hotKeySignature: OSType = {
        "PRRT".utf8.reduce(0) { result, byte in
            (result << 8) + OSType(byte)
        }
    }()

    private let handler: Handler
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [GlobalShortcutAction: EventHotKeyRef] = [:]
    private(set) var isPaused = false
    private(set) var lastRegistrationError: String?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    deinit {
        unregisterAll()
        removeEventHandler()
    }

    @discardableResult
    func start() -> Bool {
        registerAllHotKeys()
    }

    func pause() {
        unregisterAll()
        isPaused = true
    }

    @discardableResult
    func resume() -> Bool {
        registerAllHotKeys()
    }

    @discardableResult
    func reloadShortcuts() -> Bool {
        if isPaused {
            unregisterAll()
            lastRegistrationError = nil
            return true
        }

        return registerAllHotKeys()
    }

    @discardableResult
    func setPaused(_ paused: Bool) -> Bool {
        if paused {
            pause()
            return true
        }

        return resume()
    }

    func unregisterAll() {
        for hotKey in hotKeys.values {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()
    }

    private func registerAllHotKeys() -> Bool {
        unregisterAll()

        do {
            try installEventHandlerIfNeeded()
            let preferences = ShortcutPreferences.loadSaved()
            try GlobalShortcutAction.allCases.forEach { action in
                try registerHotKey(for: action, shortcut: preferences[action])
            }

            isPaused = false
            lastRegistrationError = nil
            return true
        } catch let error as GlobalShortcutRegistrationError {
            unregisterAll()
            lastRegistrationError = error.description
            return false
        } catch {
            unregisterAll()
            lastRegistrationError = "Unable to register global shortcuts."
            return false
        }
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                let manager = Unmanaged<GlobalShortcutManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return manager.handleHotKeyEvent(event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            throw GlobalShortcutRegistrationError.eventHandlerInstallFailed(status: status)
        }
    }

    private func registerHotKey(
        for action: GlobalShortcutAction,
        shortcut: KeyboardShortcutDescriptor
    ) throws {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: Self.hotKeySignature,
            id: action.rawValue
        )

        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            throw GlobalShortcutRegistrationError.hotKeyRegistrationFailed(
                action: action,
                status: status
            )
        }

        hotKeys[action] = hotKeyRef
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        guard !isPaused else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == Self.hotKeySignature,
              let action = GlobalShortcutAction(rawValue: hotKeyID.id)
        else {
            return OSStatus(eventNotHandledErr)
        }

        dispatchAction(action)
        return noErr
    }

    private func dispatchAction(_ action: GlobalShortcutAction) {
        let handler = handler

        DispatchQueue.main.async {
            handler(action)
        }
    }

    private func removeEventHandler() {
        guard let eventHandler else {
            return
        }

        RemoveEventHandler(eventHandler)
        self.eventHandler = nil
    }
}
