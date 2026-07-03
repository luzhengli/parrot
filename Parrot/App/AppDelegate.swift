import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var quickTextWindowController: NSWindowController?
    private var screenshotWindowController: NSWindowController?
    private var historyWindowController: NSWindowController?
    private var globalShortcutManager: GlobalShortcutManager?
    private var shortcutsMenuItem: NSMenuItem?
    private let screenshotOCRPipeline = ScreenshotOCRPipeline()
    private var isApplyingFloatingWindowPlacement = false
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
            keyEquivalent: "",
            systemImageName: "text.cursor"
        ))
        menu.addItem(makeMenuItem(
            title: "Screenshot Translation",
            action: #selector(showScreenshotTranslation),
            keyEquivalent: "",
            systemImageName: "text.viewfinder"
        ))
        menu.addItem(makeMenuItem(
            title: "Translation History",
            action: #selector(showTranslationHistory),
            keyEquivalent: "",
            systemImageName: "clock.arrow.circlepath"
        ))
        let shortcutsMenuItem = makeMenuItem(
            title: "Pause Shortcuts",
            action: #selector(toggleShortcuts),
            keyEquivalent: "",
            systemImageName: "pause.circle"
        )
        self.shortcutsMenuItem = shortcutsMenuItem
        menu.addItem(shortcutsMenuItem)
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: "Settings",
            action: #selector(showSettings),
            keyEquivalent: ",",
            systemImageName: "gearshape"
        ))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: "Quit Parrot",
            action: #selector(quitParrot),
            keyEquivalent: "q",
            systemImageName: "power"
        ))

        return menu
    }

    private func makeMenuItem(
        title: String,
        action: Selector,
        keyEquivalent: String,
        systemImageName: String? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        if let systemImageName,
           let image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: title) {
            image.isTemplate = true
            item.image = image
        }
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
            shortcutsMenuItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Shortcuts unavailable")
            return
        }

        if let error = globalShortcutManager.lastRegistrationError {
            shortcutsMenuItem.title = "Shortcuts Unavailable"
            shortcutsMenuItem.isEnabled = false
            shortcutsMenuItem.toolTip = error
            shortcutsMenuItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Shortcuts unavailable")
        } else if globalShortcutManager.isPaused {
            shortcutsMenuItem.title = "Resume Shortcuts"
            shortcutsMenuItem.isEnabled = true
            shortcutsMenuItem.toolTip = nil
            shortcutsMenuItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Resume shortcuts")
        } else {
            shortcutsMenuItem.title = "Pause Shortcuts"
            shortcutsMenuItem.isEnabled = true
            shortcutsMenuItem.toolTip = nil
            shortcutsMenuItem.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Pause shortcuts")
        }
    }

    @objc private func showQuickTextTranslation() {
        let view = QuickTextTranslationView(
            onClose: { [weak self] in
                self?.quickTextWindowController?.close()
            },
            onOpenHistory: { [weak self] in
                self?.showTranslationHistory()
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
            }
        )
        presentFloatingWindow(
            &quickTextWindowController,
            title: "Quick Text Translation",
            rootView: view,
            contentSize: NSSize(width: 900, height: 640),
            placement: .quickText,
            usesIntegratedTitleBar: true
        )
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
        let view = ProviderSettingsView(
            onShortcutsSaved: { [weak self] in
                self?.reloadGlobalShortcuts()
            },
            onSectionChanged: { [weak self] section in
                self?.resizeSettingsWindow(for: section, animate: true)
            },
            onOpenQuickText: { [weak self] in
                self?.showQuickTextTranslation()
            },
            onOpenScreenshot: { [weak self] in
                self?.showScreenshotTranslation()
            },
            onOpenHistory: { [weak self] in
                self?.showTranslationHistory()
            }
        )
        presentWindow(&settingsWindowController, title: "Settings", rootView: view, usesIntegratedTitleBar: true)
        resizeSettingsWindow(for: .model, animate: false)
    }

    private func resizeSettingsWindow(for section: ProviderSettingsView.Section, animate: Bool) {
        guard let window = settingsWindowController?.window else {
            return
        }

        let contentSize = NSSize(
            width: ProviderSettingsView.settingsContentWidth,
            height: section.contentHeight
        )
        let targetFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        var frame = window.frame
        let oldMaxY = frame.maxY
        frame.size = targetFrame.size
        frame.origin.y = oldMaxY - targetFrame.height
        window.setFrame(frame, display: true, animate: animate)
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
        rootView: Content,
        usesIntegratedTitleBar: Bool = false
    ) {
        if controller == nil {
            controller = makeWindowController(
                title: title,
                rootView: rootView,
                usesIntegratedTitleBar: usesIntegratedTitleBar
            )
        }

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }

    private func presentFloatingWindow<Content: View>(
        _ controller: inout NSWindowController?,
        title: String,
        rootView: Content,
        contentSize: NSSize,
        placement: FloatingWindowWorkflow,
        usesIntegratedTitleBar: Bool = false
    ) {
        if controller == nil {
            controller = makeWindowController(
                title: title,
                rootView: rootView,
                usesIntegratedTitleBar: usesIntegratedTitleBar
            )
        }

        guard let window = controller?.window else {
            return
        }

        isApplyingFloatingWindowPlacement = true
        window.setContentSize(contentSize)
        isApplyingFloatingWindowPlacement = false
        window.identifier = NSUserInterfaceItemIdentifier(placement.windowIdentifier)
        window.delegate = self
        applyFloatingWindowPlacement(to: window, placement: placement)

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        controller?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController<Content: View>(
        title: String,
        rootView: Content,
        usesIntegratedTitleBar: Bool = false
    ) -> NSWindowController {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(NSSize(width: 420, height: 240))
        window.styleMask = [.titled, .closable, .miniaturizable]
        if usesIntegratedTitleBar {
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
        }
        window.isReleasedWhenClosed = false
        window.center()

        return NSWindowController(window: window)
    }

    private func applyFloatingWindowPlacement(to window: NSWindow, placement: FloatingWindowWorkflow) {
        let savedPreference = FloatingWindowPositionPreference.loadSavedOverride()
        let visibleFrame = floatingWindowVisibleFrame(for: placement, savedPreference: savedPreference)
        let mouseLocation = NSEvent.mouseLocation
        let windowSize = window.frame.size
        let targetFrame: CGRect

        if let savedPreference {
            targetFrame = FloatingWindowPositioning.frame(
                for: savedPreference,
                windowSize: windowSize,
                visibleFrame: visibleFrame,
                mouseLocation: mouseLocation,
                lastTopLeft: FloatingWindowPositionPreference.loadLastTopLeft(),
                nearbyAnchorRect: savedPreference == .mouseNearby
                    ? CGRect(origin: mouseLocation, size: .zero)
                    : nil
            )
        } else {
            switch placement {
            case .quickText, .screenshotError:
                targetFrame = FloatingWindowPositioning.frame(
                    for: .screenCenter,
                    windowSize: windowSize,
                    visibleFrame: visibleFrame,
                    mouseLocation: mouseLocation
                )
            case .screenshotResult(let selectionRect):
                targetFrame = FloatingWindowPositioning.frameNearAnchor(
                    anchorRect: selectionRect,
                    windowSize: windowSize,
                    visibleFrame: visibleFrame
                )
            }
        }

        isApplyingFloatingWindowPlacement = true
        window.setFrame(targetFrame, display: false)
        isApplyingFloatingWindowPlacement = false
    }

    private func floatingWindowVisibleFrame(
        for placement: FloatingWindowWorkflow,
        savedPreference: FloatingWindowPositionPreference?
    ) -> CGRect {
        if savedPreference == .lastPosition,
           let lastTopLeft = FloatingWindowPositionPreference.loadLastTopLeft(),
           let screen = NSScreen.parrotScreen(containing: lastTopLeft) {
            return screen.visibleFrame
        }

        if savedPreference == .mouseNearby,
           let screen = NSScreen.parrotScreen(containing: NSEvent.mouseLocation) {
            return screen.visibleFrame
        }

        if case .screenshotResult(let selectionRect) = placement,
           let screen = NSScreen.parrotScreen(intersecting: selectionRect) {
            return screen.visibleFrame
        }

        if let screen = NSScreen.parrotScreen(containing: NSEvent.mouseLocation) ?? NSScreen.main {
            return screen.visibleFrame
        }

        return NSScreen.screens.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1024, height: 768)
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingFloatingWindowPlacement,
              let window = notification.object as? NSWindow,
              FloatingWindowWorkflow.isTrackedWindow(window)
        else {
            return
        }

        FloatingWindowPositionPreference.saveLastTopLeft(
            CGPoint(x: window.frame.minX, y: window.frame.maxY)
        )
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
            },
            onOpenHistory: { [weak self] in
                self?.showTranslationHistory()
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
            }
        )
        screenshotWindowController?.close()
        screenshotWindowController = nil
        presentFloatingWindow(
            &screenshotWindowController,
            title: "Screenshot Translation",
            rootView: view,
            contentSize: NSSize(width: 1024, height: 720),
            placement: .screenshotResult(result.screenRect),
            usesIntegratedTitleBar: true
        )
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
        screenshotWindowController?.close()
        screenshotWindowController = nil
        presentFloatingWindow(
            &screenshotWindowController,
            title: "Screenshot Translation",
            rootView: view,
            contentSize: NSSize(width: 580, height: 400),
            placement: .screenshotError,
            usesIntegratedTitleBar: true
        )
    }

    private static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            ?? URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(url)
    }
}

private enum FloatingWindowWorkflow {
    case quickText
    case screenshotResult(CGRect)
    case screenshotError

    static let quickTextIdentifier = "ParrotQuickTextTranslationWindow"
    static let screenshotIdentifier = "ParrotScreenshotTranslationWindow"

    var windowIdentifier: String {
        switch self {
        case .quickText:
            return Self.quickTextIdentifier
        case .screenshotResult, .screenshotError:
            return Self.screenshotIdentifier
        }
    }

    static func isTrackedWindow(_ window: NSWindow) -> Bool {
        guard let identifier = window.identifier?.rawValue else {
            return false
        }

        return identifier == quickTextIdentifier || identifier == screenshotIdentifier
    }
}

private extension NSScreen {
    static func parrotScreen(containing point: CGPoint) -> NSScreen? {
        screens.first { $0.frame.contains(point) }
    }

    static func parrotScreen(intersecting rect: CGRect) -> NSScreen? {
        screens
            .map { screen in
                (screen: screen, area: screen.frame.intersection(rect).area)
            }
            .filter { !$0.area.isZero }
            .max { $0.area < $1.area }?
            .screen
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
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
        VStack(spacing: 0) {
            ParrotWindowTitleBar(title: "Screenshot Translation")

            VStack(alignment: .leading, spacing: 14) {
                ParrotSurfaceHeader(
                    systemImageName: "exclamationmark.triangle.fill",
                    title: "Screenshot Capture Failed",
                    subtitle: "Parrot needs Screen Recording permission to capture other apps."
                )

                Text(message)
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                ParrotStatusBanner(
                    kind: .warning,
                    message: "Open System Settings > Privacy & Security > Screen Recording, enable Parrot, then return here and use Retry."
                )
            }
            .padding(20)

            Spacer(minLength: 0)

            ParrotFooterBar {
                Button("Open Screen Recording Settings") {
                    onOpenSettings()
                }

                Button("Retry") {
                    onRetry()
                }
            } trailing: {
                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(width: 580, height: 400, alignment: .top)
        .onExitCommand(perform: onClose)
    }
}
