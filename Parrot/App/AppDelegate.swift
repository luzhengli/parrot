import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var launchHubWindowController: NSWindowController?
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
        applyStartupActivationPolicy()

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
            self?.presentStartupEntryIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return true
        }

        showQuickTextTranslation()
        return false
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(makeMenuItem(
            title: AppLocalization.string("menu.quick_text"),
            action: #selector(showQuickTextTranslation),
            keyEquivalent: "",
            systemImageName: "text.cursor"
        ))
        menu.addItem(makeMenuItem(
            title: AppLocalization.string("menu.screenshot"),
            action: #selector(showScreenshotTranslation),
            keyEquivalent: "",
            systemImageName: "text.viewfinder"
        ))
        menu.addItem(makeMenuItem(
            title: AppLocalization.string("menu.history"),
            action: #selector(showTranslationHistory),
            keyEquivalent: "",
            systemImageName: "clock.arrow.circlepath"
        ))
        let shortcutsMenuItem = makeMenuItem(
            title: AppLocalization.string("menu.pause_shortcuts"),
            action: #selector(toggleShortcuts),
            keyEquivalent: "",
            systemImageName: "pause.circle"
        )
        self.shortcutsMenuItem = shortcutsMenuItem
        menu.addItem(shortcutsMenuItem)
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: AppLocalization.string("menu.settings"),
            action: #selector(showSettings),
            keyEquivalent: ",",
            systemImageName: "gearshape"
        ))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(
            title: AppLocalization.string("menu.quit"),
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
            shortcutsMenuItem.title = AppLocalization.string("menu.shortcuts_unavailable")
            shortcutsMenuItem.isEnabled = false
            shortcutsMenuItem.toolTip = nil
            shortcutsMenuItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: AppLocalization.string("menu.shortcuts_unavailable"))
            return
        }

        if let error = globalShortcutManager.lastRegistrationError {
            shortcutsMenuItem.title = AppLocalization.string("menu.shortcuts_unavailable")
            shortcutsMenuItem.isEnabled = false
            shortcutsMenuItem.toolTip = error
            shortcutsMenuItem.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: AppLocalization.string("menu.shortcuts_unavailable"))
        } else if globalShortcutManager.isPaused {
            shortcutsMenuItem.title = AppLocalization.string("menu.resume_shortcuts")
            shortcutsMenuItem.isEnabled = true
            shortcutsMenuItem.toolTip = nil
            shortcutsMenuItem.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: AppLocalization.string("menu.resume_shortcuts"))
        } else {
            shortcutsMenuItem.title = AppLocalization.string("menu.pause_shortcuts")
            shortcutsMenuItem.isEnabled = true
            shortcutsMenuItem.toolTip = nil
            shortcutsMenuItem.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: AppLocalization.string("menu.pause_shortcuts"))
        }
    }

    @objc private func showQuickTextTranslation() {
        let alwaysOnTopSurface = ParrotAlwaysOnTopSurface.quickText
        let view = QuickTextTranslationView(
            onClose: { [weak self] in
                self?.quickTextWindowController?.close()
            },
            onOpenHistory: { [weak self] in
                self?.showTranslationHistory()
            },
            onOpenSettings: { [weak self] in
                self?.showSettings()
            },
            onOpenSetup: { [weak self] in
                self?.showSetupChecklist()
            },
            isAlwaysOnTop: ParrotAlwaysOnTopPreferences.isEnabled(for: alwaysOnTopSurface),
            onAlwaysOnTopChanged: { [weak self] isEnabled in
                self?.setAlwaysOnTop(isEnabled, for: alwaysOnTopSurface, controller: self?.quickTextWindowController)
            }
        )
        presentFloatingWindow(
            &quickTextWindowController,
            title: AppLocalization.string("window.quick_text.title"),
            rootView: view,
            contentSize: NSSize(width: 900, height: 640),
            placement: .quickText,
            usesIntegratedTitleBar: true,
            alwaysOnTopSurface: alwaysOnTopSurface
        )
    }

    @objc private func showScreenshotTranslation() {
        prepareForegroundWindowPresentation()
        screenshotSelectionController.beginSelection()
    }

    @objc private func showTranslationHistory() {
        let alwaysOnTopSurface = ParrotAlwaysOnTopSurface.history
        let view = TranslationHistoryView(
            isAlwaysOnTop: ParrotAlwaysOnTopPreferences.isEnabled(for: alwaysOnTopSurface),
            onClose: { [weak self] in
                self?.historyWindowController?.close()
            },
            onAlwaysOnTopChanged: { [weak self] isEnabled in
                self?.setAlwaysOnTop(isEnabled, for: alwaysOnTopSurface, controller: self?.historyWindowController)
            }
        )
        presentWindow(
            &historyWindowController,
            title: AppLocalization.string("window.history.title"),
            rootView: view,
            usesIntegratedTitleBar: true,
            alwaysOnTopSurface: alwaysOnTopSurface
        )
        historyWindowController?.window?.setContentSize(NSSize(width: 760, height: 620))
    }

    private func showLaunchHub(orderFrontRegardless: Bool = false) {
        let shortcuts = ShortcutPreferences.loadSaved()
        let view = LaunchHubView(
            quickTextShortcut: shortcuts[.quickTextTranslation].displayString,
            screenshotShortcut: shortcuts[.screenshotTranslation].displayString,
            settingsShortcut: shortcuts[.openSettings].displayString,
            onOpenQuickText: { [weak self] in
                self?.launchHubWindowController?.close()
                self?.showQuickTextTranslation()
            },
            onOpenScreenshot: { [weak self] in
                self?.launchHubWindowController?.close()
                self?.showScreenshotTranslation()
            },
            onOpenHistory: { [weak self] in
                self?.launchHubWindowController?.close()
                self?.showTranslationHistory()
            },
            onOpenSettings: { [weak self] in
                self?.launchHubWindowController?.close()
                self?.showSettings()
            },
            onOpenSetup: { [weak self] in
                self?.launchHubWindowController?.close()
                self?.showSetupChecklist()
            },
            onOpenAbout: { [weak self] in
                self?.launchHubWindowController?.close()
                self?.presentSettings(initialSection: .about)
            },
            onDisableStartup: { [weak self] in
                ParrotLaunchHubPreferences.setShowOnStartup(false)
                self?.launchHubWindowController?.close()
            },
            onClose: { [weak self] in
                self?.launchHubWindowController?.close()
            }
        )

        launchHubWindowController?.close()
        launchHubWindowController = nil
        presentWindow(
            &launchHubWindowController,
            title: AppLocalization.string("window.launch_hub.title"),
            rootView: view,
            usesIntegratedTitleBar: true
        )
        launchHubWindowController?.window?.setContentSize(NSSize(width: 720, height: 520))
        if orderFrontRegardless {
            launchHubWindowController?.window?.orderFrontRegardless()
        }
    }

    @objc private func showSettings() {
        presentSettings(initialSection: .model)
    }

    @objc private func showSetupChecklist() {
        presentSettings(initialSection: .setup)
    }

    private func presentSettings(initialSection: ProviderSettingsView.Section) {
        if initialSection == .setup, settingsWindowController != nil {
            settingsWindowController?.close()
            settingsWindowController = nil
        }

        let alwaysOnTopSurface = settingsAlwaysOnTopSurface(for: initialSection)
        let view = ProviderSettingsView(
            initialSection: initialSection,
            onShortcutsSaved: { [weak self] in
                self?.reloadGlobalShortcuts()
            },
            onSectionChanged: { [weak self] section in
                guard let self else {
                    return
                }
                resizeSettingsWindow(for: section, animate: true)
                applyAlwaysOnTop(
                    for: settingsAlwaysOnTopSurface(for: section),
                    to: settingsWindowController?.window
                )
            },
            onOpenQuickText: { [weak self] in
                self?.showQuickTextTranslation()
            },
            onOpenScreenshot: { [weak self] in
                self?.showScreenshotTranslation()
            },
            onOpenHistory: { [weak self] in
                self?.showTranslationHistory()
            },
            onOpenLaunchHub: { [weak self] in
                self?.showLaunchHub()
            },
            onDockIconVisibilityChanged: { [weak self] isVisible in
                self?.applyDockIconVisibility(isVisible)
            },
            isSettingsAlwaysOnTop: ParrotAlwaysOnTopPreferences.isEnabled(for: .settings),
            isAboutAlwaysOnTop: ParrotAlwaysOnTopPreferences.isEnabled(for: .about),
            onAlwaysOnTopChanged: { [weak self] surface, isEnabled in
                self?.setAlwaysOnTop(isEnabled, for: surface, controller: self?.settingsWindowController)
            }
        )
        presentWindow(
            &settingsWindowController,
            title: AppLocalization.string("window.settings.title"),
            rootView: view,
            usesIntegratedTitleBar: true,
            alwaysOnTopSurface: alwaysOnTopSurface
        )
        resizeSettingsWindow(for: initialSection, animate: false)
        applyAlwaysOnTop(for: alwaysOnTopSurface, to: settingsWindowController?.window)
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

    private func presentStartupEntryIfNeeded() {
        switch ParrotStartupPresentation.destination(
            providerConfigurationIsValid: providerConfigurationIsValid()
        ) {
        case .setup:
            presentSettings(initialSection: .setup)
        case .launchHub:
            showLaunchHub(orderFrontRegardless: true)
        case .none:
            break
        }
    }

    private func providerConfigurationIsValid() -> Bool {
        let settings = LLMProviderSettings.loadSaved()
        let hasAPIKeyRecord = KeychainSecretStore().hasSavedAPIKeyRecord(providerID: settings.providerID)
        let hasValidEndpoint = (try? ProviderEndpointNormalizer.chatCompletionsURL(from: settings.baseURLString)) != nil
            && !settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasAPIKeyRecord && hasValidEndpoint
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

    private func setAlwaysOnTop(
        _ isEnabled: Bool,
        for surface: ParrotAlwaysOnTopSurface,
        controller: NSWindowController?
    ) {
        ParrotAlwaysOnTopPreferences.set(isEnabled, for: surface)
        applyAlwaysOnTop(isEnabled, to: controller?.window)
    }

    private func applyAlwaysOnTop(
        for surface: ParrotAlwaysOnTopSurface,
        to window: NSWindow?
    ) {
        applyAlwaysOnTop(
            ParrotAlwaysOnTopPreferences.isEnabled(for: surface),
            to: window
        )
    }

    private func applyAlwaysOnTop(_ isEnabled: Bool, to window: NSWindow?) {
        window?.level = isEnabled ? .floating : .normal
    }

    private func settingsAlwaysOnTopSurface(for section: ProviderSettingsView.Section) -> ParrotAlwaysOnTopSurface {
        section == .about ? .about : .settings
    }

    private func applyStartupActivationPolicy() {
        NSApp.setActivationPolicy(ParrotDockIconPreferences.load().showDockIcon ? .regular : .prohibited)
    }

    private func prepareForegroundWindowPresentation() {
        NSApp.setActivationPolicy(ParrotDockIconPreferences.load().showDockIcon ? .regular : .accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyDockIconVisibility(_ isVisible: Bool) {
        let visibleWindows = isVisible ? [] : NSApp.windows.filter { window in
            window.isVisible && !window.isMiniaturized
        }
        let keyWindow = isVisible ? nil : NSApp.keyWindow

        NSApp.setActivationPolicy(isVisible ? .regular : .accessory)
        if isVisible {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            restoreVisibleWindowsAfterDockIconToggle(visibleWindows, keyWindow: keyWindow)
        }
    }

    private func restoreVisibleWindowsAfterDockIconToggle(_ windows: [NSWindow], keyWindow: NSWindow?) {
        guard !windows.isEmpty else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.orderFrontRegardless()
        }
        keyWindow?.makeKeyAndOrderFront(nil)
    }

    private func presentWindow<Content: View>(
        _ controller: inout NSWindowController?,
        title: String,
        rootView: Content,
        usesIntegratedTitleBar: Bool = false,
        alwaysOnTopSurface: ParrotAlwaysOnTopSurface? = nil
    ) {
        if controller == nil {
            controller = makeWindowController(
                title: title,
                rootView: rootView,
                usesIntegratedTitleBar: usesIntegratedTitleBar
            )
        }

        prepareForegroundWindowPresentation()
        if let alwaysOnTopSurface {
            applyAlwaysOnTop(for: alwaysOnTopSurface, to: controller?.window)
        }
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }

    private func presentFloatingWindow<Content: View>(
        _ controller: inout NSWindowController?,
        title: String,
        rootView: Content,
        contentSize: NSSize,
        placement: FloatingWindowWorkflow,
        usesIntegratedTitleBar: Bool = false,
        alwaysOnTopSurface: ParrotAlwaysOnTopSurface? = nil
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
        if let alwaysOnTopSurface {
            applyAlwaysOnTop(for: alwaysOnTopSurface, to: window)
        }

        prepareForegroundWindowPresentation()
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
        let alwaysOnTopSurface = ParrotAlwaysOnTopSurface.screenshotTranslation
        let view = ScreenshotSelectionResultView(
            result: result,
            status: .recognizing,
            recognizeText: { [screenshotOCRPipeline] in
                await screenshotOCRPipeline.receive(result)
            },
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
            },
            onOpenSetup: { [weak self] in
                self?.showSetupChecklist()
            },
            isAlwaysOnTop: ParrotAlwaysOnTopPreferences.isEnabled(for: alwaysOnTopSurface),
            onAlwaysOnTopChanged: { [weak self] isEnabled in
                self?.setAlwaysOnTop(isEnabled, for: alwaysOnTopSurface, controller: self?.screenshotWindowController)
            }
        )
        screenshotWindowController?.close()
        screenshotWindowController = nil
        presentFloatingWindow(
            &screenshotWindowController,
            title: AppLocalization.string("window.screenshot.title"),
            rootView: view,
            contentSize: NSSize(width: 1024, height: 720),
            placement: .screenshotResult(result.screenRect),
            usesIntegratedTitleBar: true,
            alwaysOnTopSurface: alwaysOnTopSurface
        )
    }

    private func showScreenshotSelectionError(_ message: String) {
        let alwaysOnTopSurface = ParrotAlwaysOnTopSurface.screenshotTranslation
        let view = ScreenshotCaptureErrorView(
            message: message,
            isAlwaysOnTop: ParrotAlwaysOnTopPreferences.isEnabled(for: alwaysOnTopSurface),
            onOpenSettings: {
                Self.openScreenRecordingSettings()
            },
            onRetry: { [weak self] in
                self?.screenshotWindowController?.close()
                self?.showScreenshotTranslation()
            },
            onClose: { [weak self] in
                self?.screenshotWindowController?.close()
            },
            onAlwaysOnTopChanged: { [weak self] isEnabled in
                self?.setAlwaysOnTop(isEnabled, for: alwaysOnTopSurface, controller: self?.screenshotWindowController)
            }
        )
        screenshotWindowController?.close()
        screenshotWindowController = nil
        presentFloatingWindow(
            &screenshotWindowController,
            title: AppLocalization.string("window.screenshot.title"),
            rootView: view,
            contentSize: NSSize(width: 580, height: 400),
            placement: .screenshotError,
            usesIntegratedTitleBar: true,
            alwaysOnTopSurface: alwaysOnTopSurface
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

private struct LaunchHubView: View {
    let quickTextShortcut: String
    let screenshotShortcut: String
    let settingsShortcut: String
    let onOpenQuickText: () -> Void
    let onOpenScreenshot: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSetup: () -> Void
    let onOpenAbout: () -> Void
    let onDisableStartup: () -> Void
    let onClose: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ParrotWindowTitleBar(title: AppLocalization.string("window.launch_hub.title"))

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 52, height: 52)
                        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Parrot")
                            .font(.system(size: 24, weight: .semibold))

                        Text(AppLocalization.string("launch_hub.subtitle"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                ParrotStatusBanner(
                    kind: .info,
                    message: AppLocalization.string("launch_hub.startup_info")
                )

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    LaunchHubActionButton(
                        title: AppLocalization.string("launch_hub.quick_text.title"),
                        detail: AppLocalization.string("launch_hub.quick_text.detail"),
                        systemImageName: "text.cursor",
                        shortcut: quickTextShortcut,
                        isPrimary: true,
                        action: onOpenQuickText
                    )

                    LaunchHubActionButton(
                        title: AppLocalization.string("launch_hub.screenshot.title"),
                        detail: AppLocalization.string("launch_hub.screenshot.detail"),
                        systemImageName: "text.viewfinder",
                        shortcut: screenshotShortcut,
                        action: onOpenScreenshot
                    )

                    LaunchHubActionButton(
                        title: AppLocalization.string("launch_hub.history.title"),
                        detail: AppLocalization.string("launch_hub.history.detail"),
                        systemImageName: "clock.arrow.circlepath",
                        shortcut: nil,
                        action: onOpenHistory
                    )

                    LaunchHubActionButton(
                        title: AppLocalization.string("launch_hub.settings.title"),
                        detail: AppLocalization.string("launch_hub.settings.detail"),
                        systemImageName: "gearshape",
                        shortcut: settingsShortcut,
                        action: onOpenSettings
                    )

                    LaunchHubActionButton(
                        title: AppLocalization.string("launch_hub.onboarding.title"),
                        detail: AppLocalization.string("launch_hub.onboarding.detail"),
                        systemImageName: "checklist",
                        shortcut: nil,
                        action: onOpenSetup
                    )

                    LaunchHubActionButton(
                        title: AppLocalization.string("launch_hub.updates.title"),
                        detail: AppLocalization.string("launch_hub.updates.detail"),
                        systemImageName: "info.circle",
                        shortcut: nil,
                        action: onOpenAbout
                    )
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            ParrotFooterBar {
                Button(AppLocalization.string("launch_hub.disable_startup")) {
                    onDisableStartup()
                }
                .help(AppLocalization.string("launch_hub.disable_startup.help"))
            } trailing: {
                Button(AppLocalization.string("common.close")) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(width: 720, height: 520, alignment: .top)
        .onExitCommand(perform: onClose)
    }
}

private struct LaunchHubActionButton: View {
    let title: String
    let detail: String
    let systemImageName: String
    let shortcut: String?
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImageName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isPrimary ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let shortcut {
                        Text(shortcut)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(minHeight: 92, maxHeight: 92, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .parrotPanel(
                fill: isPrimary
                    ? Color.accentColor.opacity(0.08)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.45),
                stroke: isPrimary
                    ? Color.accentColor.opacity(0.18)
                    : Color(nsColor: .separatorColor).opacity(0.55)
            )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
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

            Text(AppLocalization.string("window.settings.title"))
                .font(.title2.bold())

            Text(AppLocalization.string("placeholder.settings.not_implemented"))
                .font(.body)
                .multilineTextAlignment(.center)

            Text(AppLocalization.string("placeholder.settings.future"))
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
    let onAlwaysOnTopChanged: (Bool) -> Void
    @State private var isAlwaysOnTop: Bool

    init(
        message: String,
        isAlwaysOnTop: Bool = false,
        onOpenSettings: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onAlwaysOnTopChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.message = message
        self.onOpenSettings = onOpenSettings
        self.onRetry = onRetry
        self.onClose = onClose
        self.onAlwaysOnTopChanged = onAlwaysOnTopChanged
        _isAlwaysOnTop = State(initialValue: isAlwaysOnTop)
    }

    var body: some View {
        VStack(spacing: 0) {
            ParrotWindowTitleBar(title: AppLocalization.string("window.screenshot.title")) {
                ParrotAlwaysOnTopButton(
                    surface: .screenshotTranslation,
                    isEnabled: $isAlwaysOnTop,
                    onChange: onAlwaysOnTopChanged
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                ParrotSurfaceHeader(
                    systemImageName: "exclamationmark.triangle.fill",
                    title: AppLocalization.string("screenshot.capture.failed.title"),
                    subtitle: AppLocalization.string("screenshot.capture.permission.subtitle")
                )

                Text(message)
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                ParrotStatusBanner(
                    kind: .warning,
                    message: AppLocalization.string("screenshot.capture.permission.message")
                )
            }
            .padding(20)

            Spacer(minLength: 0)

            ParrotFooterBar {
                Button(AppLocalization.string("screenshot.capture.open_settings")) {
                    onOpenSettings()
                }

                Button(AppLocalization.string("common.retry")) {
                    onRetry()
                }
            } trailing: {
                Button(AppLocalization.string("common.close")) {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .frame(width: 580, height: 400, alignment: .top)
        .onExitCommand(perform: onClose)
    }
}
