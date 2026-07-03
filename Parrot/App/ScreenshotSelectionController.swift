import AppKit
import CoreGraphics
import SwiftUI
import Vision

struct ScreenshotSelectionResult {
    let image: NSImage
    let screenRect: CGRect
}

private struct ScreenSnapshot {
    let screen: NSScreen
    let displayBounds: CGRect
    let image: CGImage
}

struct ScreenshotPipelineStatus {
    let title: String
    let message: String
    let recognizedText: String?
    let isSuccess: Bool
}

struct OCRSourceTextEditingState: Equatable {
    let originalRecognizedText: String
    private(set) var editedText: String

    init(recognizedText: String) {
        let trimmedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        originalRecognizedText = trimmedText
        editedText = trimmedText
    }

    var requestText: String {
        editedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasEditedText: Bool {
        requestText != originalRecognizedText
    }

    var canRequestTranslation: Bool {
        !requestText.isEmpty
    }

    mutating func updateEditedText(_ text: String) {
        editedText = text
    }
}

@MainActor
private final class ScreenshotTranslationComparisonStore: ObservableObject {
    @Published private var sourceEditingState: OCRSourceTextEditingState {
        didSet {
            handleSourceTextChange(from: oldValue)
        }
    }
    @Published var languagePreferences = TranslationLanguagePreferences.loadSaved()
    @Published private(set) var latestDetectedSource: TranslationLanguage?
    @Published private(set) var translatedText = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var isStatusError = false
    @Published private(set) var isTranslating = false

    private let keychain: KeychainSecretStore
    private var hasAttemptedTranslation = false
    private var lastTranslatedSourceText: String?

    init(sourceText: String, keychain: KeychainSecretStore = KeychainSecretStore()) {
        self.sourceEditingState = OCRSourceTextEditingState(recognizedText: sourceText)
        self.keychain = keychain
    }

    var sourceText: String {
        get {
            sourceEditingState.editedText
        }
        set {
            var updatedState = sourceEditingState
            updatedState.updateEditedText(newValue)
            sourceEditingState = updatedState
        }
    }

    var canRetry: Bool {
        sourceEditingState.canRequestTranslation && languagePreferences.validationMessage == nil && !isTranslating
    }

    var canCopySource: Bool {
        sourceEditingState.canRequestTranslation
    }

    var canCopyTranslation: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var languageValidationMessage: String? {
        languagePreferences.validationMessage
    }

    func swapLanguages() {
        languagePreferences.swapLanguages(recentDetectedSource: latestDetectedSource)
        languagePreferences.save()
    }

    func translateIfNeeded() async {
        guard !hasAttemptedTranslation else {
            return
        }

        hasAttemptedTranslation = true
        await translate()
    }

    func retryTranslation() {
        hasAttemptedTranslation = true
        Task {
            await translate()
        }
    }

    func copySource() {
        copyToPasteboard(sourceEditingState.requestText)
        statusMessage = "Original text copied."
        isStatusError = false
    }

    func copyTranslation() {
        let text = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        copyToPasteboard(text)
        statusMessage = "Translation copied."
        isStatusError = false
    }

    private func translate() async {
        let requestText = sourceEditingState.requestText
        guard !requestText.isEmpty, !isTranslating else {
            return
        }

        isTranslating = true
        latestDetectedSource = TranslationLanguageResolver.detectSourceLanguage(in: requestText)
        languagePreferences.save()
        translatedText = ""
        statusMessage = "Translating recognized text with the configured provider..."
        isStatusError = false

        do {
            let settings = LLMProviderSettings.loadSaved()
            guard keychain.hasSavedAPIKeyRecord(providerID: settings.providerID) else {
                throw ProviderSettingsError.missingAPIKey
            }

            guard let apiKey = try keychain.readAPIKey(providerID: settings.providerID), !apiKey.isEmpty else {
                throw ProviderSettingsError.missingAPIKey
            }

            let client = OpenAICompatibleProviderClient(settings: settings, apiKey: apiKey)
            let finalTranslation = try await client.translateStreaming(requestText, preferences: languagePreferences) { [weak self] delta in
                self?.translatedText += delta
            }
            translatedText = finalTranslation
            TranslationHistoryStore.shared.addRecord(
                sourceText: requestText,
                translatedText: finalTranslation,
                sourceType: "Screenshot"
            )
            lastTranslatedSourceText = requestText
            if sourceEditingState.requestText == requestText {
                statusMessage = "Translation ready."
            } else {
                translatedText = ""
                statusMessage = "Original text edited. Use Again to translate the updated text."
            }
            isStatusError = false
        } catch {
            translatedText = ""
            statusMessage = error.userFacingMessage
            isStatusError = true
        }

        isTranslating = false
    }

    private func handleSourceTextChange(from oldState: OCRSourceTextEditingState) {
        guard sourceEditingState.editedText != oldState.editedText else {
            return
        }

        let requestText = sourceEditingState.requestText
        latestDetectedSource = requestText.isEmpty
            ? nil
            : TranslationLanguageResolver.detectSourceLanguage(in: requestText)

        guard !isTranslating else {
            return
        }

        guard !requestText.isEmpty else {
            translatedText = ""
            statusMessage = "Original text is empty."
            isStatusError = true
            return
        }

        guard let lastTranslatedSourceText, lastTranslatedSourceText != requestText else {
            if isStatusError, statusMessage == "Original text is empty." {
                statusMessage = nil
                isStatusError = false
            }
            return
        }

        translatedText = ""
        statusMessage = "Original text edited. Use Again to translate the updated text."
        isStatusError = false
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

final class ScreenshotOCRPipeline {
    private(set) var lastSelection: ScreenshotSelectionResult?
    private(set) var lastRecognizedText: String?

    func receive(_ selection: ScreenshotSelectionResult) -> ScreenshotPipelineStatus {
        lastSelection = selection
        lastRecognizedText = nil

        guard let cgImage = selection.image.cgImageForOCR()?.scaledForOCR() else {
            return ScreenshotPipelineStatus(
                title: "OCR unavailable",
                message: "Unable to prepare the selected image for local text recognition. Use New Screenshot to select the region again.",
                recognizedText: nil,
                isSuccess: false
            )
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.minimumTextHeight = 0.01

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return ScreenshotPipelineStatus(
                title: "OCR failed",
                message: "Local text recognition failed: \(error.localizedDescription). Use New Screenshot to retry with a clearer region.",
                recognizedText: nil,
                isSuccess: false
            )
        }

        let recognizedText = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !recognizedText.isEmpty else {
            return ScreenshotPipelineStatus(
                title: "No text detected",
                message: "No translatable text was detected in the selected region. Use New Screenshot to select a clearer or larger area.",
                recognizedText: nil,
                isSuccess: false
            )
        }

        lastRecognizedText = recognizedText

        return ScreenshotPipelineStatus(
            title: "Text recognized locally",
            message: "OCR completed on this Mac. The screenshot image was not uploaded; only recognized text is sent to translation.",
            recognizedText: recognizedText,
            isSuccess: true
        )
    }
}

private extension NSImage {
    func cgImageForOCR() -> CGImage? {
        var imageRect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &imageRect, context: nil, hints: nil)
    }
}

private extension CGImage {
    func scaledForOCR() -> CGImage? {
        let longestSide = max(width, height)
        let scale = min(max(1, 900 / CGFloat(longestSide)), 4)
        guard scale > 1 else {
            return self
        }

        let scaledWidth = Int(CGFloat(width) * scale)
        let scaledHeight = Int(CGFloat(height) * scale)
        guard let colorSpace = colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: scaledWidth,
                height: scaledHeight,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return self
        }

        context.interpolationQuality = .high
        context.draw(self, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))
        return context.makeImage() ?? self
    }
}

struct ScreenCaptureAccessGate {
    enum Outcome: Equatable {
        case granted
        case requestPresented
        case deniedAfterRequest
    }

    private var hasPresentedRequest = false

    mutating func evaluate(
        preflight: () -> Bool = CGPreflightScreenCaptureAccess,
        request: () -> Bool = CGRequestScreenCaptureAccess
    ) -> Outcome {
        if preflight() {
            hasPresentedRequest = false
            return .granted
        }

        guard !hasPresentedRequest else {
            return .deniedAfterRequest
        }

        hasPresentedRequest = true
        return request() ? .granted : .requestPresented
    }
}

final class ScreenshotSelectionController: NSObject {
    typealias Completion = (ScreenshotSelectionResult) -> Void
    typealias Failure = (String) -> Void

    private let completion: Completion
    private let failure: Failure
    private var overlayWindows: [ScreenshotSelectionWindow] = []
    private var selectedRect: CGRect?
    private var screenSnapshots: [CGDirectDisplayID: ScreenSnapshot] = [:]
    private var screenCaptureAccessGate = ScreenCaptureAccessGate()

    init(completion: @escaping Completion, failure: @escaping Failure) {
        self.completion = completion
        self.failure = failure
    }

    func beginSelection() {
        cancelSelection()

        switch screenCaptureAccessGate.evaluate() {
        case .granted:
            break
        case .requestPresented:
            return
        case .deniedAfterRequest:
            failure("Screen Recording permission is still required before screenshot translation can capture other apps.")
            return
        }

        screenSnapshots = captureScreenSnapshots()
        guard !screenSnapshots.isEmpty else {
            failure("Unable to capture the screen before selection. Check Screen Recording permission in System Settings.")
            return
        }

        overlayWindows = NSScreen.screens.map { screen in
            let window = ScreenshotSelectionWindow(screen: screen)
            let selectionView = ScreenshotSelectionView()
            selectionView.delegate = self
            window.contentView = selectionView
            return window
        }

        overlayWindows.forEach { $0.orderFrontRegardless() }

        let mouseLocation = NSEvent.mouseLocation
        let focusedWindow = overlayWindows.first { $0.frame.contains(mouseLocation) } ?? overlayWindows.first
        focusedWindow?.makeKey()
        focusedWindow?.makeFirstResponder(focusedWindow?.contentView)
    }

    private func cancelSelection() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        selectedRect = nil
        screenSnapshots.removeAll()
    }

    private func finishSelection(in rect: CGRect) {
        selectedRect = rect
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        captureSelectedRegion()
    }

    private func captureSelectedRegion() {
        guard let selectedRect,
              let croppedImage = cropSnapshot(to: selectedRect)
        else {
            self.selectedRect = nil
            screenSnapshots.removeAll()
            failure("Unable to crop the selected screen region. Try selecting the region again.")
            return
        }

        self.selectedRect = nil
        screenSnapshots.removeAll()

        let image = NSImage(cgImage: croppedImage, size: selectedRect.size)
        completion(ScreenshotSelectionResult(image: image, screenRect: selectedRect))
    }

    private func captureScreenSnapshots() -> [CGDirectDisplayID: ScreenSnapshot] {
        NSScreen.screens.reduce(into: [:]) { snapshots, screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let image = CGWindowListCreateImage(
                    CGDisplayBounds(displayID),
                    .optionOnScreenOnly,
                    kCGNullWindowID,
                    [.bestResolution]
                  )
            else {
                return
            }

            snapshots[displayID] = ScreenSnapshot(
                screen: screen,
                displayBounds: CGDisplayBounds(displayID),
                image: image
            )
        }
    }

    private func cropSnapshot(to appKitRect: CGRect) -> CGImage? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(appKitRect) }) ?? NSScreen.main,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else {
            return nil
        }

        guard let snapshot = screenSnapshots[displayID] else {
            return nil
        }

        let screenFrame = screen.frame
        let scale = CGFloat(snapshot.image.width) / snapshot.displayBounds.width
        let xInScreen = appKitRect.minX - screenFrame.minX
        let yInScreenFromTop = screenFrame.maxY - appKitRect.maxY

        let cropRect = CGRect(
            x: xInScreen * scale,
            y: yInScreenFromTop * scale,
            width: appKitRect.width * scale,
            height: appKitRect.height * scale
        ).integral

        return snapshot.image.cropping(to: cropRect)
    }
}

extension ScreenshotSelectionController: ScreenshotSelectionViewDelegate {
    func screenshotSelectionViewDidCancel(_ view: ScreenshotSelectionView) {
        cancelSelection()
    }

    func screenshotSelectionView(_ view: ScreenshotSelectionView, didSelect rect: CGRect) {
        finishSelection(in: rect)
    }
}

private final class ScreenshotSelectionWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        hasShadow = false
    }

    override var canBecomeKey: Bool {
        true
    }
}

protocol ScreenshotSelectionViewDelegate: AnyObject {
    func screenshotSelectionViewDidCancel(_ view: ScreenshotSelectionView)
    func screenshotSelectionView(_ view: ScreenshotSelectionView, didSelect rect: CGRect)
}

final class ScreenshotSelectionView: NSView {
    weak var delegate: ScreenshotSelectionViewDelegate?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)

        guard let selectionRect, selectionRect.width >= 4, selectionRect.height >= 4 else {
            delegate?.screenshotSelectionViewDidCancel(self)
            return
        }

        guard let window else {
            delegate?.screenshotSelectionViewDidCancel(self)
            return
        }

        let screenRect = CGRect(
            x: window.frame.minX + selectionRect.minX,
            y: window.frame.minY + selectionRect.minY,
            width: selectionRect.width,
            height: selectionRect.height
        )
        delegate?.screenshotSelectionView(self, didSelect: screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            delegate?.screenshotSelectionViewDidCancel(self)
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(0.34).setFill()
        bounds.fill()

        guard let selectionRect else {
            drawInstructions()
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        selectionRect.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        selectionRect.fill()

        NSColor.white.withAlphaComponent(0.96).setStroke()
        let outerBorder = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
        outerBorder.lineWidth = 1
        outerBorder.stroke()

        NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
        let accentBorder = NSBezierPath(roundedRect: selectionRect.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
        accentBorder.lineWidth = 2
        accentBorder.stroke()

        drawSelectionSize(selectionRect)
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else {
            return nil
        }

        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    private func drawInstructions() {
        let text = "Drag to select text. Esc cancels."
        drawBadge(text, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    private func drawSelectionSize(_ rect: CGRect) {
        let text = "\(Int(rect.width)) x \(Int(rect.height))"
        let badgeSize = badgeSize(for: text)
        let origin = CGPoint(
            x: min(max(rect.minX, bounds.minX + 12), bounds.maxX - badgeSize.width - 12),
            y: min(rect.maxY + 8, bounds.maxY - badgeSize.height - 12)
        )
        drawBadge(text, at: origin)
    }

    private func drawBadge(_ text: String, centeredAt point: CGPoint) {
        let size = badgeSize(for: text)
        let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        drawBadge(text, at: origin)
    }

    private func badgeSize(for text: String) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium)
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let size = attributedText.size()
        return CGSize(width: size.width + 22, height: size.height + 14)
    }

    private func drawBadge(_ text: String, at origin: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let size = badgeSize(for: text)
        let rect = CGRect(origin: origin, size: size)

        NSColor.windowBackgroundColor.withAlphaComponent(0.92).setFill()
        let background = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        background.fill()

        NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
        background.lineWidth = 1
        background.stroke()

        attributedText.draw(
            at: CGPoint(
                x: rect.midX - attributedText.size().width / 2,
                y: rect.midY - attributedText.size().height / 2
            )
        )
    }
}

struct ScreenshotSelectionResultView: View {
    let result: ScreenshotSelectionResult
    let status: ScreenshotPipelineStatus
    let onClose: () -> Void
    let onRetrySelection: () -> Void

    @StateObject private var store: ScreenshotTranslationComparisonStore

    init(
        result: ScreenshotSelectionResult,
        status: ScreenshotPipelineStatus,
        onClose: @escaping () -> Void,
        onRetrySelection: @escaping () -> Void
    ) {
        self.result = result
        self.status = status
        self.onClose = onClose
        self.onRetrySelection = onRetrySelection
        _store = StateObject(wrappedValue: ScreenshotTranslationComparisonStore(sourceText: status.recognizedText ?? ""))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                header
                preview
                languageControls
                statusBanner
                comparison
            }
            .padding(20)

            Spacer(minLength: 0)

            footer
        }
        .frame(width: 900, height: 680, alignment: .top)
        .onChange(of: store.languagePreferences) { _, newValue in
            newValue.save()
        }
        .task {
            guard status.isSuccess else {
                return
            }

            await store.translateIfNeeded()
        }
        .onExitCommand(perform: onClose)
    }

    private var languageControls: some View {
        TranslationLanguageControls(
            preferences: $store.languagePreferences,
            latestDetectedSource: store.latestDetectedSource,
            validationMessage: store.languageValidationMessage,
            isTranslating: store.isTranslating,
            canRetranslate: store.canRetry,
            onSwap: store.swapLanguages,
            onRetranslate: store.retryTranslation
        )
    }

    private var header: some View {
        ParrotSurfaceHeader(
            systemImageName: status.isSuccess ? "text.viewfinder" : "exclamationmark.triangle.fill",
            title: "Translation Result",
            subtitle: status.isSuccess
                ? "Review OCR text, edit if needed, and copy the translated result."
                : "Review the capture problem and select a new region when ready."
        )
    }

    private var preview: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Label(status.title, systemImage: status.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(status.isSuccess ? Color.green : Color.orange)

                Text(status.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                ParrotFieldLabel(title: "Region")

                Text("x \(Int(result.screenRect.minX)), y \(Int(result.screenRect.minY))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(result.screenRect.width)) x \(Int(result.screenRect.height))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(9)
        .parrotPanel()
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let statusMessage = store.statusMessage {
            ParrotStatusBanner(
                kind: statusKind,
                message: statusMessage
            )
        }
    }

    private var comparison: some View {
        HStack(alignment: .top, spacing: 14) {
            sourceComparisonColumn

            comparisonColumn(
                title: "Translation",
                text: store.translatedText,
                placeholder: translationPlaceholder
            )
        }
    }

    private var sourceComparisonColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ParrotFieldLabel(title: "Original")

                if status.isSuccess {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Copy") {
                    store.copySource()
                }
                .buttonStyle(.borderless)
                .disabled(!store.canCopySource)
            }

            EditableComparisonTextView(
                text: sourceTextBinding,
                placeholder: status.isSuccess ? "" : "No recognized text to translate.",
                isEditable: status.isSuccess,
                onCancel: onClose
            )
            .frame(height: 270)
            .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity)
    }

    private var sourceTextBinding: Binding<String> {
        Binding(
            get: { store.sourceText },
            set: { store.sourceText = $0 }
        )
    }

    private func comparisonColumn(title: String, text: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ParrotFieldLabel(title: title)

                Spacer()

                Button("Copy") {
                    store.copyTranslation()
                }
                .buttonStyle(.borderless)
                .disabled(!store.canCopyTranslation)
            }

            ComparisonTextView(text: text, placeholder: placeholder)
                .frame(height: 270)
                .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        ParrotFooterBar {
            Button("Copy Translation") {
                store.copyTranslation()
            }
            .disabled(!store.canCopyTranslation)
            .buttonStyle(.borderedProminent)

            Button("Retry") {
                store.retryTranslation()
            }
            .disabled(!store.canRetry)

            if !status.isSuccess {
                Button("New Screenshot") {
                    onRetrySelection()
                }
            }
        } trailing: {
            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var statusKind: ParrotStatusKind {
        if store.isStatusError {
            return .error
        }

        return store.isTranslating ? .progress : .success
    }

    private var translationPlaceholder: String {
        if store.isTranslating {
            return "Waiting for translated text..."
        }

        if store.isStatusError {
            return "Translation failed. Press Retry after checking settings or network."
        }

        return status.isSuccess ? "" : "No translation available."
    }
}

private struct EditableComparisonTextView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isEditable: Bool
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = ComparisonPlaceholderTextView()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.string = text
        textView.placeholderString = placeholder
        textView.onCancel = onCancel

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ComparisonPlaceholderTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = isEditable
        textView.placeholderString = placeholder
        textView.onCancel = onCancel
        textView.needsDisplay = true
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

private struct ComparisonTextView: NSViewRepresentable {
    let text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = ComparisonPlaceholderTextView()
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
        guard let textView = scrollView.documentView as? ComparisonPlaceholderTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }
        textView.placeholderString = placeholder
        textView.needsDisplay = true
    }
}

private final class ComparisonPlaceholderTextView: NSTextView {
    var placeholderString = ""
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, let onCancel {
            onCancel()
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
