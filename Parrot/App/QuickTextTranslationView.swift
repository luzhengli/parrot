import AppKit
import SwiftUI

@MainActor
final class QuickTextTranslationStore: ObservableObject {
    @Published var sourceText = ""
    @Published var languagePreferences = TranslationLanguagePreferences.loadSaved()
    @Published private(set) var latestDetectedSource: TranslationLanguage?
    @Published private(set) var translatedText = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var isStatusError = false
    @Published private(set) var errorPresentation: UserFacingErrorPresentation?
    @Published private(set) var isTranslating = false

    private let keychain: KeychainSecretStore

    init(keychain: KeychainSecretStore = KeychainSecretStore()) {
        self.keychain = keychain
    }

    var canTranslate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && languagePreferences.validationMessage == nil
            && !isTranslating
    }

    var canCopyTranslation: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canRetry: Bool {
        isStatusError && canTranslate
    }

    var languageValidationMessage: String? {
        languagePreferences.validationMessage
    }

    func swapLanguages() {
        languagePreferences.swapLanguages(recentDetectedSource: latestDetectedSource)
        languagePreferences.save()
    }

    func translate() async {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTranslating else {
            return
        }

        isTranslating = true
        latestDetectedSource = TranslationLanguageResolver.detectSourceLanguage(in: text)
        languagePreferences.save()
        translatedText = ""
        statusMessage = "Translating with the configured provider..."
        isStatusError = false
        errorPresentation = nil

        do {
            let settings = LLMProviderSettings.loadSaved()
            guard keychain.hasSavedAPIKeyRecord(providerID: settings.providerID) else {
                throw ProviderSettingsError.missingAPIKey
            }

            guard let apiKey = try keychain.readAPIKey(providerID: settings.providerID), !apiKey.isEmpty else {
                throw ProviderSettingsError.missingAPIKey
            }

            let client = OpenAICompatibleProviderClient(settings: settings, apiKey: apiKey)
            let finalTranslation = try await client.translateStreaming(text, preferences: languagePreferences) { [weak self] delta in
                self?.translatedText += delta
            }
            translatedText = finalTranslation
            TranslationHistoryStore.shared.addRecord(
                sourceText: text,
                translatedText: finalTranslation,
                sourceType: "Quick Text"
            )
            statusMessage = "Translation ready. Press Cmd+Enter to copy and close."
            isStatusError = false
            errorPresentation = nil
        } catch {
            translatedText = ""
            statusMessage = nil
            isStatusError = true
            errorPresentation = UserFacingErrorPresentation(error: error)
        }

        isTranslating = false
    }

    func clear() {
        sourceText = ""
        translatedText = ""
        statusMessage = nil
        isStatusError = false
        errorPresentation = nil
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
        errorPresentation = nil
        return true
    }
}

struct QuickTextTranslationView: View {
    @StateObject private var store = QuickTextTranslationStore()
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header
                languageControls
                inputView
                statusView
                resultView
            }
            .padding(20)

            Spacer(minLength: 0)

            footer
        }
        .frame(width: 760, height: 600, alignment: .top)
        .onChange(of: store.languagePreferences) { _, newValue in
            newValue.save()
        }
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        ParrotSurfaceHeader(
            systemImageName: "text.cursor",
            title: "Quick Text Translation",
            subtitle: "Enter translates, Cmd+Enter copies the translation and closes, Esc closes."
        )
    }

    private var languageControls: some View {
        TranslationLanguageControls(
            preferences: $store.languagePreferences,
            latestDetectedSource: store.latestDetectedSource,
            validationMessage: store.languageValidationMessage,
            isTranslating: store.isTranslating,
            canRetranslate: store.canTranslate,
            onSwap: store.swapLanguages,
            onRetranslate: startTranslation
        )
    }

    @ViewBuilder
    private var statusView: some View {
        if let error = store.errorPresentation {
            ParrotStatusBanner(
                kind: .error,
                title: error.title,
                message: "\(error.message) \(error.recoverySuggestion)"
            )
        } else if store.isTranslating {
            ParrotStatusBanner(
                kind: .progress,
                message: store.statusMessage ?? "Translating with the configured provider..."
            )
        } else if let statusMessage = store.statusMessage {
            ParrotStatusBanner(
                kind: .success,
                message: statusMessage
            )
        }
    }

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ParrotFieldLabel(title: "Input Text")

            QuickTextEditor(
                text: $store.sourceText,
                placeholder: "Paste or type text to translate...",
                onTranslate: startTranslation,
                onCopyAndClose: copyAndClose,
                onClear: store.clear,
                onCancel: onClose
            )
            .frame(height: 116)
            .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
        }
    }

    @ViewBuilder
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ParrotFieldLabel(title: "Translation")

            ReadOnlyTranslationTextView(
                text: store.translatedText,
                placeholder: translationPlaceholder
            )
            .frame(height: 136)
            .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
        }
    }

    private var footer: some View {
        ParrotFooterBar {
            Button("Translate") {
                startTranslation()
            }
            .disabled(!store.canTranslate)
            .buttonStyle(.borderedProminent)

            Button("Copy Translation") {
                _ = store.copyTranslation()
            }
            .disabled(!store.canCopyTranslation)

            if store.canRetry {
                Button("Retry") {
                    startTranslation()
                }
            }

            Button("Clear") {
                store.clear()
            }
            .keyboardShortcut("k", modifiers: [.command])
        } trailing: {
            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var translationPlaceholder: String {
        if store.isTranslating {
            return "Waiting for translated text..."
        }

        if store.isStatusError {
            return "Translation failed. Press Retry after checking settings or network."
        }

        return "Translation appears here."
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

struct TranslationLanguageControls: View {
    @Binding var preferences: TranslationLanguagePreferences
    let latestDetectedSource: TranslationLanguage?
    let validationMessage: String?
    let isTranslating: Bool
    let canRetranslate: Bool
    let onSwap: () -> Void
    let onRetranslate: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            languagePicker(title: "Source", selection: $preferences.sourceLanguage)

            Button {
                onSwap()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .background(Color(nsColor: .controlBackgroundColor), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            }
            .help("Swap source and target languages")
            .disabled(isTranslating)

            languagePicker(title: "Target", selection: $preferences.targetLanguage)

            Divider()
                .frame(height: 24)

            languageHint
                .layoutPriority(1)

            Spacer(minLength: 4)

            Button {
                onRetranslate()
            } label: {
                Label("Again", systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
            }
            .controlSize(.small)
            .disabled(!canRetranslate)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .parrotPanel(fill: Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private func languagePicker(
        title: String,
        selection: Binding<TranslationSourceSelection>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ParrotFieldLabel(title: title)

            Picker(title, selection: selection) {
                ForEach(TranslationSourceSelection.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 118)
        }
    }

    private func languagePicker(
        title: String,
        selection: Binding<TranslationTargetSelection>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ParrotFieldLabel(title: title)

            Picker(title, selection: selection) {
                ForEach(TranslationTargetSelection.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 132)
        }
    }

    @ViewBuilder
    private var languageHint: some View {
        HStack(spacing: 6) {
            Image(systemName: validationMessage == nil ? "sparkle.magnifyingglass" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))

            Text(validationMessage ?? "Detected: \(latestDetectedSource?.displayName ?? "waiting for input")")
                .font(.system(size: 11))
                .lineLimit(1)
        }
        .foregroundStyle(validationMessage == nil ? Color.secondary : Color.orange)
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
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.string = text
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
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
