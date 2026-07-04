import CoreGraphics
import Foundation

enum FloatingWindowPositionPreference: String, CaseIterable, Codable, Identifiable {
    case screenCenter = "screen-center"
    case mouseNearby = "mouse-nearby"
    case lastPosition = "last-position"

    var id: String { rawValue }

    static let storageKey = "FloatingWindowPositionPreference"
    static let lastTopLeftStorageKey = "FloatingWindowLastTopLeft"
    static let `default`: FloatingWindowPositionPreference = .screenCenter

    var displayName: String {
        switch self {
        case .screenCenter:
            return "Screen Center"
        case .mouseNearby:
            return "Mouse Nearby"
        case .lastPosition:
            return "Last Position"
        }
    }

    var detail: String {
        switch self {
        case .screenCenter:
            return "Open lightweight translation windows in the current screen center."
        case .mouseNearby:
            return "Open lightweight translation windows near the current pointer."
        case .lastPosition:
            return "Open lightweight translation windows at the last user-moved position."
        }
    }

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> FloatingWindowPositionPreference {
        loadSavedOverride(from: userDefaults) ?? .default
    }

    static func loadSavedOverride(from userDefaults: UserDefaults = .standard) -> FloatingWindowPositionPreference? {
        guard let rawValue = userDefaults.string(forKey: storageKey) else {
            return nil
        }

        return FloatingWindowPositionPreference(rawValue: rawValue)
    }

    static func hasSavedPreference(in userDefaults: UserDefaults = .standard) -> Bool {
        loadSavedOverride(from: userDefaults) != nil
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(rawValue, forKey: Self.storageKey)
    }

    static func clearSavedPreference(from userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: storageKey)
    }

    static func saveLastTopLeft(_ point: CGPoint, to userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(StoredTopLeft(point: point)) else {
            return
        }

        userDefaults.set(data, forKey: Self.lastTopLeftStorageKey)
    }

    static func loadLastTopLeft(from userDefaults: UserDefaults = .standard) -> CGPoint? {
        guard let data = userDefaults.data(forKey: Self.lastTopLeftStorageKey),
              let storedPoint = try? JSONDecoder().decode(StoredTopLeft.self, from: data)
        else {
            return nil
        }

        return CGPoint(x: storedPoint.x, y: storedPoint.y)
    }

    private struct StoredTopLeft: Codable {
        let x: CGFloat
        let y: CGFloat

        init(point: CGPoint) {
            x = point.x
            y = point.y
        }
    }
}

enum FloatingWindowPositioning {
    static let edgePadding: CGFloat = 12
    static let anchorGap: CGFloat = 12

    static func frame(
        for preference: FloatingWindowPositionPreference,
        windowSize: CGSize,
        visibleFrame: CGRect,
        mouseLocation: CGPoint,
        lastTopLeft: CGPoint? = nil,
        nearbyAnchorRect: CGRect? = nil
    ) -> CGRect {
        switch preference {
        case .screenCenter:
            return centeredFrame(windowSize: windowSize, visibleFrame: visibleFrame)
        case .mouseNearby:
            return frameNearAnchor(
                anchorRect: nearbyAnchorRect ?? CGRect(origin: mouseLocation, size: .zero),
                windowSize: windowSize,
                visibleFrame: visibleFrame
            )
        case .lastPosition:
            guard let lastTopLeft else {
                return centeredFrame(windowSize: windowSize, visibleFrame: visibleFrame)
            }

            return frameAtTopLeft(
                lastTopLeft,
                windowSize: windowSize,
                visibleFrame: visibleFrame
            )
        }
    }

    static func centeredFrame(windowSize: CGSize, visibleFrame: CGRect) -> CGRect {
        clampedFrame(
            origin: CGPoint(
                x: visibleFrame.midX - windowSize.width / 2,
                y: visibleFrame.midY - windowSize.height / 2
            ),
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
    }

    static func frameAtTopLeft(
        _ topLeft: CGPoint,
        windowSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        clampedFrame(
            origin: CGPoint(x: topLeft.x, y: topLeft.y - windowSize.height),
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
    }

    static func frameNearAnchor(
        anchorRect: CGRect,
        windowSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let verticallyAlignedY = anchorRect.midY - windowSize.height / 2
        let horizontallyAlignedX = anchorRect.midX - windowSize.width / 2
        let candidates = [
            CGPoint(x: anchorRect.maxX + anchorGap, y: verticallyAlignedY),
            CGPoint(x: anchorRect.minX - anchorGap - windowSize.width, y: verticallyAlignedY),
            CGPoint(x: horizontallyAlignedX, y: anchorRect.maxY + anchorGap),
            CGPoint(x: horizontallyAlignedX, y: anchorRect.minY - anchorGap - windowSize.height)
        ]

        if let visibleCandidate = candidates.first(where: {
            isFullyVisible(
                CGRect(origin: $0, size: windowSize),
                in: visibleFrame
            )
        }) {
            return roundedFrame(origin: visibleCandidate, size: windowSize)
        }

        return clampedFrame(
            origin: candidates.first ?? CGPoint(x: visibleFrame.midX, y: visibleFrame.midY),
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
    }

    static func clampedFrame(
        origin: CGPoint,
        windowSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        let paddedFrame = visibleFrame.insetBy(dx: edgePadding, dy: edgePadding)
        let x = clampedCoordinate(
            proposed: origin.x,
            min: paddedFrame.minX,
            max: paddedFrame.maxX - windowSize.width,
            fallback: visibleFrame.midX - windowSize.width / 2
        )
        let y = clampedCoordinate(
            proposed: origin.y,
            min: paddedFrame.minY,
            max: paddedFrame.maxY - windowSize.height,
            fallback: visibleFrame.midY - windowSize.height / 2
        )

        return roundedFrame(origin: CGPoint(x: x, y: y), size: windowSize)
    }

    private static func isFullyVisible(_ frame: CGRect, in visibleFrame: CGRect) -> Bool {
        let paddedFrame = visibleFrame.insetBy(dx: edgePadding, dy: edgePadding)
        guard paddedFrame.width >= frame.width,
              paddedFrame.height >= frame.height
        else {
            return false
        }

        return paddedFrame.contains(frame)
    }

    private static func clampedCoordinate(
        proposed: CGFloat,
        min minimum: CGFloat,
        max maximum: CGFloat,
        fallback: CGFloat
    ) -> CGFloat {
        guard maximum >= minimum else {
            return fallback
        }

        return Swift.min(Swift.max(proposed, minimum), maximum)
    }

    private static func roundedFrame(origin: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: origin.x.rounded(),
            y: origin.y.rounded(),
            width: size.width.rounded(),
            height: size.height.rounded()
        )
    }
}
