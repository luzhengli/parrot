import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var quickTextWindowController: NSWindowController?
    private var screenshotWindowController: NSWindowController?
    private var globalShortcutManager: GlobalShortcutManager?
    private var shortcutsMenuItem: NSMenuItem?
    private let screenshotOCRPipeline = PendingScreenshotOCRPipeline()
    private lazy var screenshotSelectionController = ScreenshotSelectionController(
        completion: { [weak self] result in
            self?.handleScreenshotSelection(result)
        },
        failure: { [weak self] message in
            self?.showScreenshotSelectionError(message)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        statusItem.length = 64

        if let button = statusItem.button {
            button.title = "Parrot"
            button.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            button.toolTip = "Parrot"
        }

        statusItem.menu = makeStatusMenu()
        startGlobalShortcuts()
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(makeMenuItem(
            title: "Quick Text Translation",
            action: #selector(showQuickTextTranslation),
            keyEquivalent: ""
        ))
        menu.addItem(makeMenuItem(
            title: "Screenshot Translation",
            action: #selector(showScreenshotTranslation),
            keyEquivalent: ""
        ))
        let shortcutsMenuItem = makeMenuItem(
            title: "Pause Shortcuts",
            action: #selector(toggleShortcuts),
            keyEquivalent: ""
        )
        self.shortcutsMenuItem = shortcutsMenuItem
        menu.addItem(shortcutsMenuItem)
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: "Settings",
            action: #selector(showSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: "Quit Parrot",
            action: #selector(quitParrot),
            keyEquivalent: "q"
        ))

        return menu
    }

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func startGlobalShortcuts() {
        let manager = GlobalShortcutManager { [weak self] action in
            self?.handleGlobalShortcut(action)
        }
        globalShortcutManager = manager

        if !manager.start(), let error = manager.lastRegistrationError {
            NSLog("Global shortcut registration failed: %@", error)
        }

        updateShortcutsMenuItem()
    }

    private func handleGlobalShortcut(_ action: GlobalShortcutAction) {
        switch action {
        case .quickTextTranslation:
            showQuickTextTranslation()
        case .screenshotTranslation:
            showScreenshotTranslation()
        }
    }

    private func updateShortcutsMenuItem() {
        guard let shortcutsMenuItem else {
            return
        }

        guard let globalShortcutManager else {
            shortcutsMenuItem.title = "Shortcuts Unavailable"
            shortcutsMenuItem.isEnabled = false
            shortcutsMenuItem.toolTip = nil
            return
        }

        if let error = globalShortcutManager.lastRegistrationError {
            shortcutsMenuItem.title = "Shortcuts Unavailable"
            shortcutsMenuItem.isEnabled = false
            shortcutsMenuItem.toolTip = error
        } else if globalShortcutManager.isPaused {
            shortcutsMenuItem.title = "Resume Shortcuts"
            shortcutsMenuItem.isEnabled = true
            shortcutsMenuItem.toolTip = nil
        } else {
            shortcutsMenuItem.title = "Pause Shortcuts"
            shortcutsMenuItem.isEnabled = true
            shortcutsMenuItem.toolTip = nil
        }
    }

    @objc private func showQuickTextTranslation() {
        let view = FeaturePlaceholderView(
            title: "Quick Text Translation",
            systemImageName: "text.cursor",
            description: "Quick text translation is not implemented yet.",
            detail: "This menu action is wired so the app can expose the intended workflow while the dedicated translation feature is built."
        )
        presentWindow(&quickTextWindowController, title: "Quick Text Translation", rootView: view)
    }

    @objc private func showScreenshotTranslation() {
        NSApp.setActivationPolicy(.accessory)
        screenshotSelectionController.beginSelection()
    }

    @objc private func showSettings() {
        presentWindow(&settingsWindowController, title: "Settings", rootView: SettingsPlaceholderView())
    }

    @objc private func toggleShortcuts() {
        guard let globalShortcutManager else {
            updateShortcutsMenuItem()
            return
        }

        if globalShortcutManager.isPaused {
            if !globalShortcutManager.resume(), let error = globalShortcutManager.lastRegistrationError {
                NSLog("Global shortcut registration failed: %@", error)
            }
        } else {
            globalShortcutManager.pause()
        }

        updateShortcutsMenuItem()
    }

    @objc private func quitParrot() {
        NSApp.terminate(nil)
    }

    private func presentWindow<Content: View>(
        _ controller: inout NSWindowController?,
        title: String,
        rootView: Content
    ) {
        if controller == nil {
            controller = makeWindowController(title: title, rootView: rootView)
        }

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController<Content: View>(title: String, rootView: Content) -> NSWindowController {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(NSSize(width: 420, height: 240))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        return NSWindowController(window: window)
    }

    private func handleScreenshotSelection(_ result: ScreenshotSelectionResult) {
        let status = screenshotOCRPipeline.receive(result)
        let view = ScreenshotSelectionResultView(result: result, status: status)
        screenshotWindowController = makeWindowController(title: "Screenshot Translation", rootView: view)
        screenshotWindowController?.window?.setContentSize(NSSize(width: 520, height: 360))

        NSApp.activate(ignoringOtherApps: true)
        screenshotWindowController?.showWindow(nil)
        screenshotWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func showScreenshotSelectionError(_ message: String) {
        let view = FeaturePlaceholderView(
            title: "Screenshot Capture Failed",
            systemImageName: "exclamationmark.triangle",
            description: message,
            detail: "Open System Settings > Privacy & Security > Screen Recording, enable Parrot, then try again."
        )
        screenshotWindowController = makeWindowController(title: "Screenshot Translation", rootView: view)

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        screenshotWindowController?.showWindow(nil)
        screenshotWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.tint)

            Text("Settings")
                .font(.title2.bold())

            Text("Provider settings are not implemented yet.")
                .font(.body)
                .multilineTextAlignment(.center)

            Text("Future settings will configure an OpenAI-compatible base URL, model, and Keychain-backed API key.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeaturePlaceholderView: View {
    let title: String
    let systemImageName: String
    let description: String
    let detail: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImageName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.tint)

            Text(title)
                .font(.title2.bold())

            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
