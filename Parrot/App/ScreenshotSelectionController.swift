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

enum ScreenshotPipelinePhase: Equatable {
    case recognizing
    case success
    case failure
}

struct ScreenshotPipelineStatus: Equatable {
    let title: String
    let message: String
    let recognizedText: String?
    let phase: ScreenshotPipelinePhase

    init(
        title: String,
        message: String,
        recognizedText: String?,
        isSuccess: Bool
    ) {
        self.title = title
        self.message = message
        self.recognizedText = recognizedText
        self.phase = isSuccess ? .success : .failure
    }

    private init(
        title: String,
        message: String,
        recognizedText: String?,
        phase: ScreenshotPipelinePhase
    ) {
        self.title = title
        self.message = message
        self.recognizedText = recognizedText
        self.phase = phase
    }

    static let recognizing = ScreenshotPipelineStatus(
        title: AppLocalization.string("screenshot.ocr.recognizing.title"),
        message: AppLocalization.string("screenshot.ocr.recognizing.message"),
        recognizedText: nil,
        phase: .recognizing
    )

    var isRecognizing: Bool {
        phase == .recognizing
    }

    var isSuccess: Bool {
        phase == .success
    }
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
    private enum TranslationControlFlow: Error {
        case awaitingLargeTextConfirmation
    }

    private struct SegmentRetryState {
        let sourceText: String
        let preferences: TranslationLanguagePreferences
        var outputs: [Int: String]
        var failedSegmentIndex: Int
    }

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
    @Published private(set) var errorPresentation: UserFacingErrorPresentation?
    @Published private(set) var isTranslating = false
    @Published private(set) var requiresLargeTextConfirmation = false

    private let keychain: KeychainSecretStore
    private let clientFactory: TranslationClientFactory
    private let historyRecorder: @MainActor (String, String, String) -> Void
    private let requestCoordinator = TranslationRequestCoordinator()
    private var hasAttemptedTranslation = false
    private var lastTranslatedSourceText: String?
    private var segmentRetryState: SegmentRetryState?
    private var isReplacingRecognizedText = false

    init(
        sourceText: String,
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
        self.sourceEditingState = OCRSourceTextEditingState(recognizedText: sourceText)
        self.keychain = keychain
        self.clientFactory = clientFactory
        self.historyRecorder = historyRecorder
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

    func loadRecognizedText(_ recognizedText: String) {
        cancelTranslation(showStatus: false)
        isReplacingRecognizedText = true
        sourceEditingState = OCRSourceTextEditingState(recognizedText: recognizedText)
        isReplacingRecognizedText = false
        translatedText = ""
        statusMessage = nil
        isStatusError = false
        errorPresentation = nil
        isTranslating = false
        requiresLargeTextConfirmation = false
        hasAttemptedTranslation = false
        lastTranslatedSourceText = nil
        segmentRetryState = nil
        let requestText = sourceEditingState.requestText
        latestDetectedSource = requestText.isEmpty
            ? nil
            : TranslationLanguageResolver.detectSourceLanguage(in: requestText)
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
        let task = startTranslation()
        await task?.value
    }

    func retryTranslation() {
        hasAttemptedTranslation = true
        startTranslation(retryFailedSegmentOnly: true)
    }

    func confirmLargeTextTranslation() {
        hasAttemptedTranslation = true
        startTranslation(allowLargeText: true)
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

    func copySource() {
        copyToPasteboard(sourceEditingState.requestText)
        statusMessage = AppLocalization.string("screenshot.status.original_copied")
        isStatusError = false
        errorPresentation = nil
    }

    func copyTranslation() {
        let text = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        copyToPasteboard(text)
        statusMessage = AppLocalization.string("screenshot.status.translation_copied")
        isStatusError = false
        errorPresentation = nil
    }

    @discardableResult
    private func startTranslation(allowLargeText: Bool = false, retryFailedSegmentOnly: Bool = false) -> Task<Void, Never>? {
        let requestText = sourceEditingState.requestText
        guard !requestText.isEmpty else {
            return nil
        }
        if isTranslating {
            cancelTranslation(showStatus: false)
        }

        isTranslating = true
        requiresLargeTextConfirmation = false
        latestDetectedSource = TranslationLanguageResolver.detectSourceLanguage(in: requestText)
        languagePreferences.save()
        if !retryFailedSegmentOnly {
            translatedText = ""
            segmentRetryState = nil
        }
        statusMessage = AppLocalization.string("screenshot.status.translating")
        isStatusError = false
        errorPresentation = nil

        let requestID = requestCoordinator.beginRequest()
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await self.runTranslation(
                requestID: requestID,
                requestText: requestText,
                allowLargeText: allowLargeText,
                retryFailedSegmentOnly: retryFailedSegmentOnly
            )
        }
        requestCoordinator.attachTask(task, to: requestID)
        return task
    }

    private func runTranslation(
        requestID: TranslationRequestID,
        requestText: String,
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
                requestText: requestText,
                client: client,
                allowLargeText: allowLargeText,
                retryFailedSegmentOnly: retryFailedSegmentOnly
            )
            guard requestCoordinator.isActive(requestID) else {
                return
            }
            translatedText = finalTranslation
            historyRecorder(requestText, finalTranslation, "Screenshot")
            lastTranslatedSourceText = requestText
            if sourceEditingState.requestText == requestText {
                statusMessage = AppLocalization.string("screenshot.status.ready")
            } else {
                translatedText = ""
                statusMessage = AppLocalization.string("screenshot.status.source_edited")
            }
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
        requestText: String,
        client: TranslationStreamingProviding,
        allowLargeText: Bool,
        retryFailedSegmentOnly: Bool
    ) async throws -> String {
        let plan = LongTextTranslationPlanner.plan(for: requestText, allowLargeText: allowLargeText)
        switch plan {
        case .single:
            return try await performSingleTranslation(requestID: requestID, requestText: requestText, client: client)
        case .segmented(let segments):
            return try await performSegmentedTranslation(
                requestID: requestID,
                requestText: requestText,
                segments: segments,
                client: client,
                retryFailedSegmentOnly: retryFailedSegmentOnly
            )
        case .requiresConfirmation(let characterCount, _):
            requiresLargeTextConfirmation = true
            translatedText = ""
            statusMessage = AppLocalization.format("screenshot.status.large_text", characterCount)
            isStatusError = true
            errorPresentation = nil
            throw TranslationControlFlow.awaitingLargeTextConfirmation
        }
    }

    private func performSingleTranslation(
        requestID: TranslationRequestID,
        requestText: String,
        client: TranslationStreamingProviding
    ) async throws -> String {
        try Task.checkCancellation()
        statusMessage = AppLocalization.string("screenshot.status.translating")
        let finalTranslation = try await client.translateStreaming(
            requestText,
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
        requestText: String,
        segments: [TranslationSegment],
        client: TranslationStreamingProviding,
        retryFailedSegmentOnly: Bool
    ) async throws -> String {
        let retryState = retryFailedSegmentOnly ? segmentRetryState : nil
        var outputs = retryState?.sourceText == requestText && retryState?.preferences == languagePreferences
            ? retryState?.outputs ?? [:]
            : [:]
        let startIndex = retryState?.sourceText == requestText && retryState?.preferences == languagePreferences
            ? retryState?.failedSegmentIndex ?? 0
            : 0
        segmentRetryState = nil

        for segment in segments where segment.index >= startIndex {
            try Task.checkCancellation()
            guard requestCoordinator.isActive(requestID) else {
                throw CancellationError()
            }

            statusMessage = AppLocalization.format("screenshot.status.segment_progress", segment.index + 1, segments.count)
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
                        sourceText: requestText,
                        preferences: languagePreferences,
                        outputs: outputs,
                        failedSegmentIndex: segment.index
                    )
                    statusMessage = AppLocalization.format("screenshot.status.segment_failed", segment.index + 1, segments.count)
                    isStatusError = true
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

    private func handleSourceTextChange(from oldState: OCRSourceTextEditingState) {
        guard !isReplacingRecognizedText else {
            return
        }

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
            statusMessage = AppLocalization.string("screenshot.status.original_empty")
            isStatusError = true
            errorPresentation = nil
            return
        }

        guard let lastTranslatedSourceText, lastTranslatedSourceText != requestText else {
            if isStatusError, statusMessage == AppLocalization.string("screenshot.status.original_empty") {
                statusMessage = nil
                isStatusError = false
                errorPresentation = nil
            }
            return
        }

        translatedText = ""
        statusMessage = AppLocalization.string("screenshot.status.source_edited")
        isStatusError = false
        errorPresentation = nil
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

final class ScreenshotOCRPipeline {
    private(set) var lastSelection: ScreenshotSelectionResult?
    private(set) var lastRecognizedText: String?

    func receive(_ selection: ScreenshotSelectionResult) async -> ScreenshotPipelineStatus {
        lastSelection = selection
        lastRecognizedText = nil

        guard let cgImage = selection.image.cgImageForOCR()?.scaledForOCR() else {
            return ScreenshotPipelineStatus(
                title: AppLocalization.string("screenshot.ocr.unavailable.title"),
                message: AppLocalization.string("screenshot.ocr.unavailable.message"),
                recognizedText: nil,
                isSuccess: false
            )
        }

        let status = await Task.detached(priority: .userInitiated) {
            Self.recognizeText(in: cgImage)
        }.value

        if !Task.isCancelled, let recognizedText = status.recognizedText {
            lastRecognizedText = recognizedText
        }

        return status
    }

    private static func recognizeText(in cgImage: CGImage) -> ScreenshotPipelineStatus {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.minimumTextHeight = 0.01

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return ScreenshotPipelineStatus(
                title: AppLocalization.string("screenshot.ocr.failed.title"),
                message: AppLocalization.format("screenshot.ocr.failed.message", error.localizedDescription),
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
                title: AppLocalization.string("screenshot.ocr.no_text.title"),
                message: AppLocalization.string("screenshot.ocr.no_text.message"),
                recognizedText: nil,
                isSuccess: false
            )
        }

        return ScreenshotPipelineStatus(
            title: AppLocalization.string("screenshot.ocr.success.title"),
            message: AppLocalization.string("screenshot.ocr.success.message"),
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
            failure(AppLocalization.string("screenshot.capture.permission.required"))
            return
        }

        screenSnapshots = captureScreenSnapshots()
        guard !screenSnapshots.isEmpty else {
            failure(AppLocalization.string("screenshot.capture.unable"))
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
            failure(AppLocalization.string("screenshot.capture.crop_failed"))
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
        let text = AppLocalization.string("screenshot.selection.instructions")
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
    let onClose: () -> Void
    let onRetrySelection: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSetup: () -> Void
    let onAlwaysOnTopChanged: (Bool) -> Void
    let recognizeText: () async -> ScreenshotPipelineStatus

    @State private var status: ScreenshotPipelineStatus
    @State private var isAlwaysOnTop: Bool
    @StateObject private var store: ScreenshotTranslationComparisonStore

    init(
        result: ScreenshotSelectionResult,
        status: ScreenshotPipelineStatus,
        recognizeText: @escaping () async -> ScreenshotPipelineStatus = {
            ScreenshotPipelineStatus(
                title: AppLocalization.string("screenshot.ocr.unavailable.title"),
                message: AppLocalization.string("screenshot.ocr.unavailable.message"),
                recognizedText: nil,
                isSuccess: false
            )
        },
        onClose: @escaping () -> Void,
        onRetrySelection: @escaping () -> Void,
        onOpenHistory: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onOpenSetup: @escaping () -> Void = {},
        isAlwaysOnTop: Bool = false,
        onAlwaysOnTopChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.result = result
        self.onClose = onClose
        self.onRetrySelection = onRetrySelection
        self.onOpenHistory = onOpenHistory
        self.onOpenSettings = onOpenSettings
        self.onOpenSetup = onOpenSetup
        self.onAlwaysOnTopChanged = onAlwaysOnTopChanged
        self.recognizeText = recognizeText
        _status = State(initialValue: status)
        _isAlwaysOnTop = State(initialValue: isAlwaysOnTop)
        _store = StateObject(wrappedValue: ScreenshotTranslationComparisonStore(sourceText: status.recognizedText ?? ""))
    }

    var body: some View {
        VStack(spacing: 0) {
            ParrotWindowTitleBar(title: AppLocalization.string("window.screenshot.title")) {
                HStack(spacing: 8) {
                    ParrotAlwaysOnTopButton(
                        surface: .screenshotTranslation,
                        isEnabled: $isAlwaysOnTop,
                        onChange: onAlwaysOnTopChanged
                    )
                    ParrotTitleBarIconButton(systemName: "clock.arrow.circlepath", title: AppLocalization.string("window.history.title"), action: onOpenHistory)
                    ParrotTitleBarIconButton(systemName: "gearshape", title: AppLocalization.string("window.settings.title"), action: onOpenSettings)
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                header
                preview
                statusBanner
                comparison
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)

            Spacer(minLength: 0)

            footer
        }
        .frame(width: 1024, height: 720, alignment: .top)
        .onChange(of: store.languagePreferences) { _, newValue in
            newValue.save()
        }
        .task {
            await runInitialOCRAndTranslation()
        }
        .onExitCommand(perform: cancelAndClose)
        .onDisappear {
            store.cancelTranslation(showStatus: false)
        }
    }

    private var header: some View {
        ParrotSurfaceHeader(
            systemImageName: status.isSuccess || status.isRecognizing ? "viewfinder" : "exclamationmark.triangle.fill",
            title: status.isRecognizing ? AppLocalization.string("window.screenshot.title") : AppLocalization.string("window.screenshot.result_title"),
            subtitle: status.isRecognizing
                ? AppLocalization.string("screenshot.header.recognizing.subtitle")
                : status.isSuccess
                    ? AppLocalization.string("screenshot.header.success.subtitle")
                    : AppLocalization.string("screenshot.header.failure.subtitle")
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
                if status.isRecognizing {
                    HStack(spacing: 7) {
                        ProgressView()
                            .controlSize(.small)

                        Text(status.title)
                            .font(.callout.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                } else {
                    Label(status.isSuccess ? AppLocalization.string("screenshot.preview.ocr_complete") : status.title, systemImage: status.isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(status.isSuccess ? Color.accentColor : Color.orange)
                }

                Text(status.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(status.isSuccess ? 1 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                ParrotFieldLabel(title: AppLocalization.string("screenshot.region"))

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
        if status.isRecognizing {
            ParrotStatusPill(kind: .progress, message: AppLocalization.string("screenshot.status.recognizing"))
        } else if let validationMessage = store.languageValidationMessage {
            ParrotStatusPill(kind: .warning, message: validationMessage)
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
        } else if let statusMessage = store.statusMessage {
            ParrotStatusPill(kind: statusKind, message: statusMessage)
        }
    }

    private var comparison: some View {
        HStack(alignment: .top, spacing: 14) {
            sourceComparisonColumn

            comparisonColumn(
                title: AppLocalization.string("screenshot.translation"),
                text: store.translatedText,
                placeholder: translationPlaceholder
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var sourceComparisonColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ParrotFieldLabel(title: AppLocalization.string("screenshot.original"), uppercase: true)

                SourceLanguageMenu(
                    selection: $store.languagePreferences.sourceLanguage,
                    isDisabled: store.isTranslating
                )

                if status.isSuccess {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(AppLocalization.string("common.copy")) {
                    store.copySource()
                }
                .buttonStyle(.borderless)
                .disabled(!store.canCopySource)
            }

            EditableComparisonTextView(
                text: sourceTextBinding,
                placeholder: sourcePlaceholder,
                isEditable: status.isSuccess,
                onCancel: cancelAndClose
            )
            .frame(height: 360)
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
            HStack(spacing: 8) {
                ParrotFieldLabel(title: title, uppercase: true)

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

                Spacer()

                Button(AppLocalization.string("common.copy")) {
                    store.copyTranslation()
                }
                .buttonStyle(.borderless)
                .disabled(!store.canCopyTranslation)
            }

            ComparisonTextView(text: text, placeholder: placeholder)
                .frame(height: 360)
                .parrotPanel(fill: Color(nsColor: .textBackgroundColor))
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        ParrotFooterBar {
            Button(AppLocalization.string("common.copy_translation")) {
                store.copyTranslation()
            }
            .disabled(!store.canCopyTranslation)
            .buttonStyle(.borderedProminent)

            Button(AppLocalization.string("common.retry")) {
                store.retryTranslation()
            }
            .disabled(!store.canRetry)

            if store.requiresLargeTextConfirmation {
                Button(AppLocalization.string("quick_text.button.translate_anyway")) {
                    store.confirmLargeTextTranslation()
                }
                .disabled(store.isTranslating)
            }

            if !status.isSuccess || status.isRecognizing {
                Button(AppLocalization.string("screenshot.button.new")) {
                    cancelAndRetrySelection()
                }
            }
        } trailing: {
            Button(AppLocalization.string("common.close")) {
                cancelAndClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var statusKind: ParrotStatusKind {
        if status.isRecognizing {
            return .progress
        }

        if store.isStatusError {
            return .error
        }

        return store.isTranslating ? .progress : .success
    }

    private var translationPlaceholder: String {
        if status.isRecognizing {
            return AppLocalization.string("screenshot.placeholder.translation_after_ocr")
        }

        if store.isTranslating {
            return AppLocalization.string("screenshot.placeholder.waiting")
        }

        if store.isStatusError {
            return AppLocalization.string("screenshot.placeholder.failed")
        }

        return status.isSuccess ? "" : AppLocalization.string("screenshot.placeholder.none")
    }

    private var sourcePlaceholder: String {
        status.isRecognizing
            ? AppLocalization.string("screenshot.placeholder.recognizing")
            : status.isSuccess ? "" : AppLocalization.string("screenshot.placeholder.no_text")
    }

    private func runInitialOCRAndTranslation() async {
        if status.isRecognizing {
            let completedStatus = await recognizeText()
            guard !Task.isCancelled else {
                return
            }

            status = completedStatus
            if let recognizedText = completedStatus.recognizedText, completedStatus.isSuccess {
                store.loadRecognizedText(recognizedText)
            }
        }

        guard !Task.isCancelled, status.isSuccess else {
            return
        }

        await store.translateIfNeeded()
    }

    private func cancelAndClose() {
        store.cancelTranslation(showStatus: false)
        onClose()
    }

    private func cancelAndRetrySelection() {
        store.cancelTranslation(showStatus: false)
        onRetrySelection()
    }

    private func errorBannerMessage(for error: UserFacingErrorPresentation) -> String {
        [store.statusMessage, "\(error.message) \(error.recoverySuggestion)"]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private func performRecoveryAction(_ action: UserFacingErrorRecoveryAction) {
        switch action {
        case .openSetup:
            onOpenSetup()
        case .openModelSettings:
            onOpenSettings()
        case .retry:
            store.retryTranslation()
        }
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
