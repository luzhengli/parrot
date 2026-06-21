import AppKit
import CoreGraphics
import SwiftUI

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
}

final class PendingScreenshotOCRPipeline {
    private(set) var lastSelection: ScreenshotSelectionResult?

    func receive(_ selection: ScreenshotSelectionResult) -> ScreenshotPipelineStatus {
        lastSelection = selection

        return ScreenshotPipelineStatus(
            title: "Screenshot captured",
            message: "The selected image region has been handed to the OCR pipeline placeholder. Local OCR will be implemented in the dedicated OCR feature."
        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(status.title)
                        .font(.title3.bold())

                    Text(status.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Image(nsImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.secondary.opacity(0.35))
                }

            Text("Selected region: x \(Int(result.screenRect.minX)), y \(Int(result.screenRect.minY)), \(Int(result.screenRect.width)) x \(Int(result.screenRect.height))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 520)
    }
}
