import AppKit
import SwiftUI

@MainActor
final class QuickTextTranslationStore: ObservableObject {
    @Published var sourceText = ""
    @Published private(set) var translatedText = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var isStatusError = false
    @Published private(set) var isTranslating = false

    private let keychain: KeychainSecretStore

    init(keychain: KeychainSecretStore = KeychainSecretStore()) {
        self.keychain = keychain
    }

    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTranslating
    }

    var canCopyTranslation: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func translate() async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTranslating else {
            return
        }

        isTranslating = true
        translatedText = ""
        statusMessage = "Translating with the configured provider..."
        isStatusError = false

        do {
            let settings = LLMProviderSettings.loadSaved()
            guard let apiKey = try keychain.readAPIKey(providerID: settings.providerID), !apiKey.isEmpty else {
                throw ProviderSettingsError.missingAPIKey
            }

            let client = OpenAICompatibleProviderClient(settings: settings, apiKey: apiKey)
            let finalTranslation = try await client.translateStreaming(text) { [weak self] delta in
                self?.translatedText += delta
            }
            translatedText = finalTranslation
            statusMessage = "Translation ready. Press Cmd+Enter to copy and close."
            isStatusError = false
        } catch {
            translatedText = ""
            statusMessage = error.localizedDescription
            isStatusError = true
        }

        isTranslating = false
    }

    func clear() {
        sourceText = ""
        translatedText = ""
        statusMessage = nil
        isStatusError = false
    }

    @discardableResult
    func copyTranslation() -> Bool {
        let text = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return false
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "Translation copied."
        isStatusError = false
        return true
    }
}

struct QuickTextTranslationView: View {
    @StateObject private var store = QuickTextTranslationStore()
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            QuickTextEditor(
                text: $store.sourceText,
                placeholder: "Paste or type text to translate...",
                onTranslate: startTranslation,
                onCopyAndClose: copyAndClose,
                onClear: store.clear,
                onCancel: onClose
            )
            .frame(height: 120)

            statusView
            resultView
            footer
        }
        .padding(20)
        .frame(width: 560)
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.tint)

                Text("Quick Text Translation")
                    .font(.title3.bold())
            }

            Text("Enter translates, Cmd+Enter copies the translation and closes, Esc closes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let statusMessage = store.statusMessage {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: store.isStatusError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(store.isStatusError ? .orange : .green)

                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(store.isStatusError ? .primary : .secondary)
                    .textSelection(.enabled)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Translation")
                .font(.headline)

            ReadOnlyTranslationTextView(
                text: store.translatedText,
                placeholder: store.isTranslating ? "Waiting for translated text..." : ""
            )
            .frame(height: 170)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var footer: some View {
        HStack {
            Button("Translate") {
                startTranslation()
            }
            .disabled(!store.canTranslate)

            Button("Copy Translation") {
                _ = store.copyTranslation()
            }
            .disabled(!store.canCopyTranslation)

            Button("Clear") {
                store.clear()
            }
            .keyboardShortcut("k", modifiers: [.command])

            Spacer()

            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private func startTranslation() {
        Task {
            await store.translate()
        }
    }

    private func copyAndClose() {
        Task {
            if !store.canCopyTranslation {
                await store.translate()
            }

            if store.copyTranslation() {
                onClose()
            }
        }
    }
}

private struct QuickTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onTranslate: () -> Void
    let onCopyAndClose: () -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.onTranslate = onTranslate
        textView.onCopyAndClose = onCopyAndClose
        textView.onClear = onClear
        textView.onCancel = onCancel

        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? KeyHandlingTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }

        textView.placeholderString = placeholder
        textView.onTranslate = onTranslate
        textView.onCopyAndClose = onCopyAndClose
        textView.onClear = onClear
        textView.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text = textView.string
        }
    }
}

private final class KeyHandlingTextView: NSTextView {
    var placeholderString: String? {
        didSet {
            needsDisplay = true
        }
    }
    var onTranslate: (() -> Void)?
    var onCopyAndClose: (() -> Void)?
    var onClear: (() -> Void)?
    var onCancel: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 53 {
            onCancel?()
            return
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            if modifiers.contains(.command) {
                onCopyAndClose?()
            } else if modifiers.isDisjoint(with: [.shift, .option, .control, .command]) {
                onTranslate?()
            } else {
                super.keyDown(with: event)
            }
            return
        }

        if modifiers.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "k" {
            onClear?()
            return
        }

        super.keyDown(with: event)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, let placeholderString, !placeholderString.isEmpty else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let inset = textContainerInset
        placeholderString.draw(
            at: CGPoint(x: inset.width + 4, y: inset.height),
            withAttributes: attributes
        )
    }
}

private struct ReadOnlyTranslationTextView: NSViewRepresentable {
    let text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = PlaceholderTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.placeholderString = placeholder

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }
        textView.placeholderString = placeholder
        textView.needsDisplay = true
    }
}

private final class PlaceholderTextView: NSTextView {
    var placeholderString = ""

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholderString.isEmpty else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let inset = textContainerInset
        placeholderString.draw(
            at: CGPoint(x: inset.width + 4, y: inset.height),
            withAttributes: attributes
        )
    }
}

struct QuickTextTranslationView_Previews: PreviewProvider {
    static var previews: some View {
        QuickTextTranslationView(onClose: {})
    }
}
