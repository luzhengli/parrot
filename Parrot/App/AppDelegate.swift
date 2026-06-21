import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private var quickTextWindowController: NSWindowController?
    private var screenshotWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Parrot") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Parrot"
            }
        }

        statusItem.menu = makeStatusMenu()
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
        let view = FeaturePlaceholderView(
            title: "Screenshot Translation",
            systemImageName: "camera.viewfinder",
            description: "Screenshot translation is not implemented yet.",
            detail: "Region selection, local OCR, and translation results will be added in their own feature work."
        )
        presentWindow(&screenshotWindowController, title: "Screenshot Translation", rootView: view)
    }

    @objc private func showSettings() {
        presentWindow(&settingsWindowController, title: "Settings", rootView: SettingsPlaceholderView())
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
