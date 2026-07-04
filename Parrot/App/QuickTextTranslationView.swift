import AppKit
import SwiftUI

@MainActor
final class QuickTextTranslationStore: ObservableObject {
    private enum TranslationControlFlow: Error {
        case awaitingLargeTextConfirmation
    }

    private struct SegmentRetryState {
        let sourceText: String
        let preferences: TranslationLanguagePreferences
        let segments: [TranslationSegment]
        var outputs: [Int: String]
        var failedSegmentIndex: Int
    }

    @Published var sourceText = ""
    @Published var languagePreferences = TranslationLanguagePreferences.loadSaved()
    @Published private(set) var latestDetectedSource: TranslationLanguage?
    @Published private(set) var translatedText = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var isStatusError = false
    @Published private(set) var errorPresentation: UserFacingErrorPresentation?
    @Published private(set) var isTranslating = false
    @Published private(set) var requiresLargeTextConfirmation = false

    private let keychain: KeychainSecretStore
    private let clientFactory: TranslationClientFactory
    private let historyRecorder: @MainActor (String, String, String) -> Void
    private let requestCoordinator = TranslationRequestCoordinator()
    private var segmentRetryState: SegmentRetryState?

    init(
        keychain: KeychainSecretStore = KeychainSecretStore(),
        clientFactory: @escaping TranslationClientFactory = { settings, apiKey in
            OpenAICompatibleProviderClient(settings: settings, apiKey: apiKey)
        },
        historyRecorder: @escaping @MainActor (String, String, String) -> Void = { sourceText, translatedText, sourceType in
            TranslationHistoryStore.shared.addRecord(
                sourceText: sourceText,
                translatedText: translatedText,
                sourceType: sourceType
            )
        }
    ) {
        self.keychain = keychain
        self.clientFactory = clientFactory
        self.historyRecorder = historyRecorder
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

    var canConfirmLargeTextTranslation: Bool {
        requiresLargeTextConfirmation && canTranslate
    }

    var languageValidationMessage: String? {
        languagePreferences.validationMessage
    }

    func swapLanguages() {
        languagePreferences.swapLanguages(recentDetectedSource: latestDetectedSource)
        languagePreferences.save()
    }

    @discardableResult
    func startTranslation(allowLargeText: Bool = false, retryFailedSegmentOnly: Bool = false) -> Task<Void, Never>? {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }
        if isTranslating {
            cancelTranslation(showStatus: false)
        }

        isTranslating = true
        requiresLargeTextConfirmation = false
        latestDetectedSource = TranslationLanguageResolver.detectSourceLanguage(in: text)
        languagePreferences.save()
        if !retryFailedSegmentOnly {
            translatedText = ""
            segmentRetryState = nil
        }
        statusMessage = AppLocalization.string("quick_text.status.translating")
        isStatusError = false
        errorPresentation = nil

        let requestID = requestCoordinator.beginRequest()
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await self.runTranslation(
                requestID: requestID,
                text: text,
                allowLargeText: allowLargeText,
                retryFailedSegmentOnly: retryFailedSegmentOnly
            )
        }
        requestCoordinator.attachTask(task, to: requestID)
        return task
    }

    func cancelTranslation(showStatus: Bool = true) {
        let hadActiveRequest = isTranslating || requestCoordinator.hasActiveRequest
        requestCoordinator.cancelActiveRequest()
        isTranslating = false
        requiresLargeTextConfirmation = false

        if showStatus, hadActiveRequest {
            statusMessage = AppLocalization.string("quick_text.status.canceled")
            isStatusError = false
            errorPresentation = nil
        }
    }

    private func runTranslation(
        requestID: TranslationRequestID,
        text: String,
        allowLargeText: Bool,
        retryFailedSegmentOnly: Bool
    ) async {
        do {
            let settings = LLMProviderSettings.loadSaved()
            guard keychain.hasSavedAPIKeyRecord(providerID: settings.providerID) else {
                throw ProviderSettingsError.missingAPIKey
            }

            guard let apiKey = try keychain.readAPIKey(providerID: settings.providerID), !apiKey.isEmpty else {
                throw ProviderSettingsError.missingAPIKey
            }

            let client = clientFactory(settings, apiKey)
            let finalTranslation = try await performTranslation(
                requestID: requestID,
                text: text,
                client: client,
                allowLargeText: allowLargeText,
                retryFailedSegmentOnly: retryFailedSegmentOnly
            )
            guard requestCoordinator.isActive(requestID) else {
                return
            }
            translatedText = finalTranslation
            historyRecorder(text, finalTranslation, "Quick Text")
            statusMessage = AppLocalization.string("quick_text.status.ready")
            isStatusError = false
            errorPresentation = nil
            segmentRetryState = nil
        } catch TranslationControlFlow.awaitingLargeTextConfirmation {
            // Keep the confirmation status already prepared in performTranslation.
        } catch is CancellationError {
            if requestCoordinator.isActive(requestID) {
                statusMessage = AppLocalization.string("quick_text.status.canceled")
                isStatusError = false
                errorPresentation = nil
            }
        } catch {
            guard requestCoordinator.isActive(requestID) else {
                return
            }
            if segmentRetryState == nil {
                translatedText = ""
                statusMessage = nil
            }
            isStatusError = true
            if errorPresentation == nil {
                errorPresentation = UserFacingErrorPresentation(error: error)
            }
        }

        if requestCoordinator.isActive(requestID) {
            isTranslating = false
            requestCoordinator.finishRequest(requestID)
        }
    }

    private func performTranslation(
        requestID: TranslationRequestID,
        text: String,
        client: TranslationStreamingProviding,
        allowLargeText: Bool,
        retryFailedSegmentOnly: Bool
    ) async throws -> String {
        let plan = LongTextTranslationPlanner.plan(for: text, allowLargeText: allowLargeText)
        switch plan {
        case .single:
            return try await performSingleTranslation(requestID: requestID, text: text, client: client)
        case .segmented(let segments):
            return try await performSegmentedTranslation(
                requestID: requestID,
                sourceText: text,
                segments: segments,
                client: client,
                retryFailedSegmentOnly: retryFailedSegmentOnly
            )
        case .requiresConfirmation(let characterCount, let segments):
            requiresLargeTextConfirmation = true
            translatedText = ""
            statusMessage = AppLocalization.format("quick_text.status.large_text", characterCount, segments.count)
            isStatusError = true
            throw TranslationControlFlow.awaitingLargeTextConfirmation
        }
    }

    private func performSingleTranslation(
        requestID: TranslationRequestID,
        text: String,
        client: TranslationStreamingProviding
    ) async throws -> String {
        try Task.checkCancellation()
        statusMessage = AppLocalization.string("quick_text.status.translating")
        let finalTranslation = try await client.translateStreaming(
            text,
            preferences: languagePreferences,
            style: TranslationStyle.loadSaved(),
            promptPreferences: TranslationPromptPreferences.loadSaved(),
            glossaryEntries: nil
        ) { [weak self] delta in
            guard let self, self.requestCoordinator.isActive(requestID) else {
                return
            }
            self.translatedText += delta
        }
        try Task.checkCancellation()
        return finalTranslation
    }

    private func performSegmentedTranslation(
        requestID: TranslationRequestID,
        sourceText: String,
        segments: [TranslationSegment],
        client: TranslationStreamingProviding,
        retryFailedSegmentOnly: Bool
    ) async throws -> String {
        let retryState = retryFailedSegmentOnly ? segmentRetryState : nil
        var outputs = retryState?.sourceText == sourceText && retryState?.preferences == languagePreferences
            ? retryState?.outputs ?? [:]
            : [:]
        let startIndex = retryState?.sourceText == sourceText && retryState?.preferences == languagePreferences
            ? retryState?.failedSegmentIndex ?? 0
            : 0
        segmentRetryState = nil

        for segment in segments where segment.index >= startIndex {
            try Task.checkCancellation()
            guard requestCoordinator.isActive(requestID) else {
                throw CancellationError()
            }

            statusMessage = AppLocalization.format("quick_text.status.segment_progress", segment.index + 1, segments.count)
            var segmentBuffer = ""

            do {
                let segmentTranslation = try await client.translateStreaming(
                    segment.text,
                    preferences: languagePreferences,
                    style: TranslationStyle.loadSaved(),
                    promptPreferences: TranslationPromptPreferences.loadSaved(),
                    glossaryEntries: nil
                ) { [weak self] delta in
                    guard let self, self.requestCoordinator.isActive(requestID) else {
                        return
                    }
                    segmentBuffer += delta
                    outputs[segment.index] = segmentBuffer
                    self.translatedText = self.combinedSegmentOutput(outputs, segmentCount: segments.count)
                }
                outputs[segment.index] = segmentTranslation
                translatedText = combinedSegmentOutput(outputs, segmentCount: segments.count)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if requestCoordinator.isActive(requestID) {
                    segmentRetryState = SegmentRetryState(
                        sourceText: sourceText,
                        preferences: languagePreferences,
                        segments: segments,
                        outputs: outputs,
                        failedSegmentIndex: segment.index
                    )
                    statusMessage = AppLocalization.format("quick_text.status.segment_failed", segment.index + 1, segments.count)
                    isStatusError = true
                    errorPresentation = UserFacingErrorPresentation(error: error)
                }
                throw error
            }
        }

        let finalTranslation = combinedSegmentOutput(outputs, segmentCount: segments.count)
        guard !finalTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderSettingsError.unexpectedResponse
        }
        return finalTranslation
    }

    private func combinedSegmentOutput(_ outputs: [Int: String], segmentCount: Int) -> String {
        (0..<segmentCount)
            .compactMap { outputs[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    func clear() {
        cancelTranslation(showStatus: false)
        sourceText = ""
        translatedText = ""
        statusMessage = nil
        isStatusError = false
        errorPresentation = nil
        requiresLargeTextConfirmation = false
        segmentRetryState = nil
    }

    @discardableResult
    func copyTranslation() -> Bool {
        let text = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return false
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = AppLocalization.string("quick_text.status.copied")
        isStatusError = false
        errorPresentation = nil
        return true
    }
}

struct QuickTextTranslationView: View {
    @StateObject private var store = QuickTextTranslationStore()
    @State private var isAlwaysOnTop: Bool
    let onClose: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSetup: () -> Void
    let onAlwaysOnTopChanged: (Bool) -> Void

    init(
        onClose: @escaping () -> Void,
        onOpenHistory: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onOpenSetup: @escaping () -> Void = {},
        isAlwaysOnTop: Bool = false,
        onAlwaysOnTopChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _isAlwaysOnTop = State(initialValue: isAlwaysOnTop)
        self.onClose = onClose
        self.onOpenHistory = onOpenHistory
        self.onOpenSettings = onOpenSettings
        self.onOpenSetup = onOpenSetup
        self.onAlwaysOnTopChanged = onAlwaysOnTopChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            ParrotWindowTitleBar(title: AppLocalization.string("window.quick_text.title")) {
                HStack(spacing: 8) {
                    ParrotAlwaysOnTopButton(
                        surface: .quickText,
                        isEnabled: $isAlwaysOnTop,
                        onChange: onAlwaysOnTopChanged
                    )
                    ParrotTitleBarIconButton(systemName: "clock.arrow.circlepath", title: AppLocalization.string("window.history.title"), action: onOpenHistory)
                    ParrotTitleBarIconButton(systemName: "gearshape", title: AppLocalization.string("window.settings.title"), action: onOpenSettings)
                }
            }

            VStack(alignment: .leading, spacing: 20) {
                header
                inputView
                statusView
                resultView
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)

            Spacer(minLength: 0)

            footer
        }
        .frame(width: 900, height: 640, alignment: .top)
        .onChange(of: store.languagePreferences) { _, newValue in
            newValue.save()
        }
        .onExitCommand(perform: cancelAndClose)
        .onDisappear {
            store.cancelTranslation(showStatus: false)
        }
    }

    private var header: some View {
        ParrotSurfaceHeader(
            systemImageName: "translate",
            title: AppLocalization.string("window.quick_text.title"),
            subtitle: AppLocalization.string("quick_text.header.subtitle")
        )
    }

    @ViewBuilder
    private var statusView: some View {
        if let validationMessage = store.languageValidationMessage {
            ParrotStatusBanner(
                kind: .warning,
                message: validationMessage
            )
        } else if let error = store.errorPresentation {
            ParrotStatusBanner(
                kind: .error,
                title: error.title,
                message: errorBannerMessage(for: error),
                actionTitle: error.recoveryAction.title,
                actionSystemImageName: error.recoveryAction.systemImageName,
                action: {
                    performRecoveryAction(error.recoveryAction)
                }
            )
        } else if store.isTranslating {
            ParrotStatusBanner(
                kind: .progress,
                message: store.statusMessage ?? AppLocalization.string("quick_text.status.translating")
            )
        } else if let statusMessage = store.statusMessage {
            ParrotStatusBanner(
                kind: store.isStatusError ? .warning : .success,
                message: statusMessage
            )
        }
    }

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                ParrotFieldLabel(title: AppLocalization.string("quick_text.input.label"))

                Spacer()

                if let latestDetectedSource = store.latestDetectedSource {
                    Text(AppLocalization.format("quick_text.detected", latestDetectedSource.displayName))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                SourceLanguageMenu(
                    selection: $store.languagePreferences.sourceLanguage,
                    isDisabled: store.isTranslating
                )
            }

            QuickTextEditor(
                text: $store.sourceText,
                placeholder: AppLocalization.string("quick_text.input.placeholder"),
                onTranslate: startTranslation,
                onCopyAndClose: copyAndClose,
                onClear: store.clear,
                onCancel: cancelAndClose
            )
            .frame(height: 128)
            .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
        }
    }

    @ViewBuilder
    private var resultView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                ParrotFieldLabel(title: AppLocalization.string("quick_text.translation.label"))

                Spacer()

                Button {
                    store.swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help(AppLocalization.string("language.help.swap"))
                .disabled(store.isTranslating)

                TargetLanguageMenu(
                    selection: $store.languagePreferences.targetLanguage,
                    isDisabled: store.isTranslating
                )

                Button {
                    startTranslation()
                } label: {
                    Label(AppLocalization.string("common.again"), systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .controlSize(.small)
                .disabled(!store.canTranslate)
            }

            ReadOnlyTranslationTextView(
                text: store.translatedText,
                placeholder: translationPlaceholder
            )
            .frame(height: 128)
            .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
        }
    }

    private var footer: some View {
        ParrotFooterBar {
            Button(AppLocalization.string("common.translate")) {
                startTranslation()
            }
            .disabled(!store.canTranslate)
            .buttonStyle(.borderedProminent)

            Button(AppLocalization.string("common.copy_translation")) {
                _ = store.copyTranslation()
            }
            .disabled(!store.canCopyTranslation)

            if store.canRetry {
                Button(AppLocalization.string("common.retry")) {
                    retryTranslation()
                }
            }

            if store.canConfirmLargeTextTranslation {
                Button(AppLocalization.string("quick_text.button.translate_anyway")) {
                    startTranslation(allowLargeText: true)
                }
            }

            Button(AppLocalization.string("quick_text.button.clear")) {
                store.clear()
            }
            .keyboardShortcut("k", modifiers: [.command])
        } trailing: {
            Button(AppLocalization.string("common.close")) {
                cancelAndClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var translationPlaceholder: String {
        if store.isTranslating {
            return AppLocalization.string("quick_text.translation.placeholder.waiting")
        }

        if store.isStatusError {
            return AppLocalization.string("quick_text.translation.placeholder.failed")
        }

        return AppLocalization.string("quick_text.translation.placeholder.idle")
    }

    private func startTranslation() {
        store.startTranslation()
    }

    private func startTranslation(allowLargeText: Bool) {
        store.startTranslation(allowLargeText: allowLargeText)
    }

    private func retryTranslation() {
        store.startTranslation(retryFailedSegmentOnly: true)
    }

    private func performRecoveryAction(_ action: UserFacingErrorRecoveryAction) {
        switch action {
        case .openSetup:
            onOpenSetup()
        case .openModelSettings:
            onOpenSettings()
        case .retry:
            retryTranslation()
        }
    }

    private func errorBannerMessage(for error: UserFacingErrorPresentation) -> String {
        [store.statusMessage, "\(error.message) \(error.recoverySuggestion)"]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func copyAndClose() {
        Task {
            if !store.canCopyTranslation {
                let task = store.startTranslation()
                await task?.value
            }

            if store.copyTranslation() {
                cancelAndClose()
            }
        }
    }

    private func cancelAndClose() {
        store.cancelTranslation(showStatus: false)
        onClose()
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
            languagePicker(title: AppLocalization.string("language.source"), selection: $preferences.sourceLanguage)

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
            .help(AppLocalization.string("language.help.swap"))
            .disabled(isTranslating)

            languagePicker(title: AppLocalization.string("language.target"), selection: $preferences.targetLanguage)

            Divider()
                .frame(height: 24)

            languageHint
                .layoutPriority(1)

            Spacer(minLength: 4)

            Button {
                onRetranslate()
            } label: {
                Label(AppLocalization.string("common.again"), systemImage: "arrow.clockwise")
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

            Text(validationMessage ?? AppLocalization.format(
                "language.detected",
                latestDetectedSource?.displayName ?? AppLocalization.string("language.detected_waiting")
            ))
                .font(.system(size: 11))
                .lineLimit(1)
        }
        .foregroundStyle(validationMessage == nil ? Color.secondary : Color.orange)
    }
}

struct SourceLanguageMenu: View {
    @Binding var selection: TranslationSourceSelection
    var isDisabled = false

    var body: some View {
        Menu {
            ForEach(TranslationSourceSelection.allCases) { language in
                Button {
                    selection = language
                } label: {
                    menuItem(language.displayName, isSelected: selection == language)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.displayName)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tint)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(isDisabled)
        .help(AppLocalization.string("language.help.source"))
        .accessibilityLabel(AppLocalization.string("language.source"))
    }

    @ViewBuilder
    private func menuItem(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

struct TargetLanguageMenu: View {
    @Binding var selection: TranslationTargetSelection
    var isDisabled = false

    var body: some View {
        Menu {
            ForEach(TranslationTargetSelection.allCases) { language in
                Button {
                    selection = language
                } label: {
                    menuItem(language.displayName, isSelected: selection == language)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.displayName)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.tint)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(isDisabled)
        .help(AppLocalization.string("language.help.target"))
        .accessibilityLabel(AppLocalization.string("language.target"))
    }

    @ViewBuilder
    private func menuItem(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
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
