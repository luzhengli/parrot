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

@MainActor
private final class ScreenshotTranslationComparisonStore: ObservableObject {
    let sourceText: String

    @Published private(set) var translatedText = ""
    @Published private(set) var statusMessage: String?
    @Published private(set) var isStatusError = false
    @Published private(set) var isTranslating = false

    private let keychain: KeychainSecretStore
    private var hasAttemptedTranslation = false

    init(sourceText: String, keychain: KeychainSecretStore = KeychainSecretStore()) {
        self.sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.keychain = keychain
    }

    var canRetry: Bool {
        !sourceText.isEmpty && !isTranslating
    }

    var canCopySource: Bool {
        !sourceText.isEmpty
    }

    var canCopyTranslation: Bool {
        !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        copyToPasteboard(sourceText)
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
        guard !sourceText.isEmpty, !isTranslating else {
            return
        }

        isTranslating = true
        translatedText = ""
        statusMessage = "Translating recognized text with the configured provider..."
        isStatusError = false

        do {
            let settings = LLMProviderSettings.loadSaved()
            guard let apiKey = try keychain.readAPIKey(providerID: settings.providerID), !apiKey.isEmpty else {
                throw ProviderSettingsError.missingAPIKey
            }

            let client = OpenAICompatibleProviderClient(settings: settings, apiKey: apiKey)
            let finalTranslation = try await client.translateStreaming(sourceText) { [weak self] delta in
                self?.translatedText += delta
            }
            translatedText = finalTranslation
            statusMessage = "Translation ready."
            isStatusError = false
        } catch {
            translatedText = ""
            statusMessage = error.localizedDescription
            isStatusError = true
        }

        isTranslating = false
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
                message: "Unable to prepare the selected image for local text recognition. Try selecting the region again.",
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
                message: "Local text recognition failed: \(error.localizedDescription)",
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
                message: "No translatable text was detected in the selected region. Try selecting a clearer or larger area.",
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

final class ScreenshotSelectionController: NSObject {
    typealias Completion = (ScreenshotSelectionResult) -> Void
    typealias Failure = (String) -> Void

    private let completion: Completion
    private let failure: Failure
    private var overlayWindows: [ScreenshotSelectionWindow] = []
    private var selectedRect: CGRect?
    private var screenSnapshots: [CGDirectDisplayID: ScreenSnapshot] = [:]

    init(completion: @escaping Completion, failure: @escaping Failure) {
        self.completion = completion
        self.failure = failure
    }

    func beginSelection() {
        cancelSelection()

        guard ensureScreenCaptureAccess() else {
            failure("Screen Recording permission is required before screenshot translation can capture other apps.")
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

    private func ensureScreenCaptureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        return CGRequestScreenCaptureAccess()
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

        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        guard let selectionRect else {
            drawInstructions()
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        selectionRect.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.95).setStroke()
        let border = NSBezierPath(rect: selectionRect)
        border.lineWidth = 2
        border.stroke()

        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        selectionRect.fill()
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
        let text = "Drag to select a region. Press Esc to cancel."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let size = attributedText.size()
        let rect = CGRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        attributedText.draw(in: rect)
    }
}

struct ScreenshotSelectionResultView: View {
    let result: ScreenshotSelectionResult
    let status: ScreenshotPipelineStatus
    let onClose: () -> Void

    @StateObject private var store: ScreenshotTranslationComparisonStore

    init(result: ScreenshotSelectionResult, status: ScreenshotPipelineStatus, onClose: @escaping () -> Void) {
        self.result = result
        self.status = status
        self.onClose = onClose
        _store = StateObject(wrappedValue: ScreenshotTranslationComparisonStore(sourceText: status.recognizedText ?? ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            preview
            statusBanner
            comparison
            footer
        }
        .padding(24)
        .frame(width: 760)
        .task {
            guard status.isSuccess else {
                return
            }

            await store.translateIfNeeded()
        }
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: status.isSuccess ? "text.viewfinder" : "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(status.isSuccess ? Color.accentColor : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Screenshot Translation")
                    .font(.title3.bold())

                Text("Compare the recognized original text with the streaming translation.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var preview: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.35))
                }

            VStack(alignment: .leading, spacing: 8) {
                Label(status.title, systemImage: status.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(status.isSuccess ? .green : .orange)

                Text(status.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text("Selected region: x \(Int(result.screenRect.minX)), y \(Int(result.screenRect.minY)), \(Int(result.screenRect.width)) x \(Int(result.screenRect.height))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let statusMessage = store.statusMessage {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: statusIconName)
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

    private var comparison: some View {
        HStack(alignment: .top, spacing: 14) {
            comparisonColumn(
                title: "Original",
                text: store.sourceText,
                placeholder: status.isSuccess ? "" : "No recognized text to translate."
            )

            comparisonColumn(
                title: "Translation",
                text: store.translatedText,
                placeholder: translationPlaceholder
            )
        }
    }

    private func comparisonColumn(title: String, text: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ComparisonTextView(text: text, placeholder: placeholder)
                .frame(height: 240)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Copy Translation") {
                store.copyTranslation()
            }
            .disabled(!store.canCopyTranslation)

            Button("Copy Original") {
                store.copySource()
            }
            .disabled(!store.canCopySource)

            Button("Retry") {
                store.retryTranslation()
            }
            .disabled(!store.canRetry)

            Spacer()

            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var statusIconName: String {
        if store.isStatusError {
            return "exclamationmark.triangle.fill"
        }

        return store.isTranslating ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill"
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
