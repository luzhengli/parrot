import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var quickTextWindowController: NSWindowController?
    private var screenshotWindowController: NSWindowController?
    private var historyWindowController: NSWindowController?
    private var globalShortcutManager: GlobalShortcutManager?
    private var shortcutsMenuItem: NSMenuItem?
    private let screenshotOCRPipeline = ScreenshotOCRPipeline()
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
        statusItem.length = NSStatusItem.squareLength

        if let button = statusItem.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            image?.size = NSSize(width: 20, height: 20)
            button.image = image
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Parrot"
        }

        statusItem.menu = makeStatusMenu()
        startGlobalShortcuts()

        DispatchQueue.main.async { [weak self] in
            self?.showProviderSetupIfNeeded()
        }
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
        menu.addItem(makeMenuItem(
            title: "Translation History",
            action: #selector(showTranslationHistory),
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
        case .openSettings:
            showSettings()
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
        let view = QuickTextTranslationView { [weak self] in
            self?.quickTextWindowController?.close()
        }
        presentWindow(&quickTextWindowController, title: "Quick Text Translation", rootView: view)
        quickTextWindowController?.window?.setContentSize(NSSize(width: 600, height: 560))
    }

    @objc private func showScreenshotTranslation() {
        NSApp.setActivationPolicy(.accessory)
        screenshotSelectionController.beginSelection()
    }

    @objc private func showTranslationHistory() {
        let view = TranslationHistoryView { [weak self] in
            self?.historyWindowController?.close()
        }
        presentWindow(&historyWindowController, title: "Translation History", rootView: view)
        historyWindowController?.window?.setContentSize(NSSize(width: 760, height: 580))
    }

    @objc private func showSettings() {
        let view = ProviderSettingsView { [weak self] in
            self?.reloadGlobalShortcuts()
        }
        presentWindow(&settingsWindowController, title: "Settings", rootView: view)
        settingsWindowController?.window?.setContentSize(NSSize(width: 680, height: 560))
    }

    private func showProviderSetupIfNeeded() {
        let settings = LLMProviderSettings.loadSaved()
        guard !KeychainSecretStore().hasSavedAPIKeyRecord(providerID: settings.providerID) else {
            return
        }

        showSettings()
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

    private func reloadGlobalShortcuts() {
        guard let globalShortcutManager else {
            updateShortcutsMenuItem()
            return
        }

        if !globalShortcutManager.reloadShortcuts(), let error = globalShortcutManager.lastRegistrationError {
            NSLog("Global shortcut registration failed: %@", error)
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
        let view = ScreenshotSelectionResultView(
            result: result,
            status: status,
            onClose: { [weak self] in
                self?.screenshotWindowController?.close()
            },
            onRetrySelection: { [weak self] in
                self?.screenshotWindowController?.close()
                self?.showScreenshotTranslation()
            }
        )
        screenshotWindowController = makeWindowController(title: "Screenshot Translation", rootView: view)
        screenshotWindowController?.window?.setContentSize(NSSize(width: 800, height: 620))

        NSApp.activate(ignoringOtherApps: true)
        screenshotWindowController?.showWindow(nil)
        screenshotWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func showScreenshotSelectionError(_ message: String) {
        let view = ScreenshotCaptureErrorView(
            message: message,
            onOpenSettings: {
                Self.openScreenRecordingSettings()
            },
            onRetry: { [weak self] in
                self?.screenshotWindowController?.close()
                self?.showScreenshotTranslation()
            },
            onClose: { [weak self] in
                self?.screenshotWindowController?.close()
            }
        )
        screenshotWindowController = makeWindowController(title: "Screenshot Translation", rootView: view)
        screenshotWindowController?.window?.setContentSize(NSSize(width: 520, height: 320))

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        screenshotWindowController?.showWindow(nil)
        screenshotWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(url)
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

struct ScreenshotCaptureErrorView: View {
    let message: String
    let onOpenSettings: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Screenshot Capture Failed")
                        .font(.title3.bold())

                    Text("Parrot needs Screen Recording permission to capture other apps.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text(message)
                .font(.body)
                .textSelection(.enabled)

            Text("Open System Settings > Privacy & Security > Screen Recording, enable Parrot, then return here and use Retry.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack {
                Button("Open Screen Recording Settings") {
                    onOpenSettings()
                }

                Button("Retry") {
                    onRetry()
                }

                Spacer()

                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onExitCommand(perform: onClose)
    }
}
