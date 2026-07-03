import CoreGraphics
import Foundation

enum FloatingWindowPositionPreferencesE2EFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message):
            return message
        }
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw FloatingWindowPositionPreferencesE2EFailure.assertion(message)
    }
}

@main
struct FloatingWindowPositionPreferencesE2E {
    static func main() throws {
        let suiteName = "parrot-floating-window-position-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FloatingWindowPositionPreferencesE2EFailure.assertion("Unable to create isolated UserDefaults suite.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(
            FloatingWindowPositionPreference.loadSavedOverride(from: defaults) == nil,
            "A fresh install should not have an explicit floating window override."
        )
        try require(
            FloatingWindowPositionPreference.loadSaved(from: defaults) == .screenCenter,
            "Quick Text should default to Screen Center when no override is saved."
        )

        FloatingWindowPositionPreference.mouseNearby.save(to: defaults)
        try require(
            FloatingWindowPositionPreference.loadSavedOverride(from: defaults) == .mouseNearby,
            "Mouse Nearby preference should persist."
        )
        try require(
            FloatingWindowPositionPreference.hasSavedPreference(in: defaults),
            "Saved preference should be detectable."
        )

        FloatingWindowPositionPreference.lastPosition.save(to: defaults)
        try require(
            FloatingWindowPositionPreference.loadSaved(from: defaults) == .lastPosition,
            "Last Position preference should persist."
        )

        defaults.set("unknown-position", forKey: FloatingWindowPositionPreference.storageKey)
        try require(
            FloatingWindowPositionPreference.loadSaved(from: defaults) == .screenCenter,
            "Invalid saved preference should fall back to Screen Center."
        )
        FloatingWindowPositionPreference.clearSavedPreference(from: defaults)
        try require(
            !FloatingWindowPositionPreference.hasSavedPreference(in: defaults),
            "Clearing the preference should restore workflow defaults."
        )

        FloatingWindowPositionPreference.saveLastTopLeft(CGPoint(x: 180, y: 520), to: defaults)
        try require(
            FloatingWindowPositionPreference.loadLastTopLeft(from: defaults) == CGPoint(x: 180, y: 520),
            "Last window top-left should persist without storing screenshot geometry."
        )

        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 700)
        let windowSize = CGSize(width: 300, height: 200)

        let centeredFrame = FloatingWindowPositioning.frame(
            for: .screenCenter,
            windowSize: windowSize,
            visibleFrame: visibleFrame,
            mouseLocation: CGPoint(x: 40, y: 40)
        )
        try require(centeredFrame.origin == CGPoint(x: 350, y: 250), "Screen Center should center inside the visible frame.")

        let mouseFrame = FloatingWindowPositioning.frame(
            for: .mouseNearby,
            windowSize: windowSize,
            visibleFrame: visibleFrame,
            mouseLocation: CGPoint(x: 100, y: 120)
        )
        try require(mouseFrame.origin == CGPoint(x: 112, y: 20), "Mouse Nearby should place the window beside the pointer when space allows.")

        let lastPositionFrame = FloatingWindowPositioning.frame(
            for: .lastPosition,
            windowSize: windowSize,
            visibleFrame: visibleFrame,
            mouseLocation: CGPoint(x: 40, y: 40),
            lastTopLeft: CGPoint(x: 180, y: 520)
        )
        try require(lastPositionFrame.origin == CGPoint(x: 180, y: 320), "Last Position should restore the saved top-left point.")

        let screenshotAnchor = CGRect(x: 100, y: 260, width: 120, height: 120)
        let screenshotNearbyFrame = FloatingWindowPositioning.frameNearAnchor(
            anchorRect: screenshotAnchor,
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
        try require(
            screenshotNearbyFrame.origin == CGPoint(x: 232, y: 220),
            "Screenshot default placement should prefer the selected region when space allows."
        )

        let rightEdgeAnchor = CGRect(x: 880, y: 260, width: 80, height: 120)
        let leftFallbackFrame = FloatingWindowPositioning.frameNearAnchor(
            anchorRect: rightEdgeAnchor,
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
        try require(
            leftFallbackFrame.maxX <= rightEdgeAnchor.minX - FloatingWindowPositioning.anchorGap,
            "Screenshot placement should try the opposite side when the right side has no space."
        )

        let crampedVisibleFrame = CGRect(x: 0, y: 0, width: 260, height: 180)
        let visibleFallbackFrame = FloatingWindowPositioning.frameNearAnchor(
            anchorRect: CGRect(x: 220, y: 120, width: 40, height: 40),
            windowSize: windowSize,
            visibleFrame: crampedVisibleFrame
        )
        try require(
            visibleFallbackFrame.midX == crampedVisibleFrame.midX
                && visibleFallbackFrame.midY == crampedVisibleFrame.midY,
            "When the window cannot fully fit, placement should fall back to the visible screen center."
        )

        let persistedDefaults = defaults.dictionaryRepresentation()
        let persistedText = persistedDefaults
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
        try require(!persistedText.contains("screenRect"), "Floating window preferences should not persist screenshot rectangles.")
        try require(!persistedText.contains("image"), "Floating window preferences should not persist screenshot images.")
        try require(!persistedText.contains("base64"), "Floating window preferences should not persist encoded screenshot data.")

        print("floating-window-position-preferences-e2e passed")
    }
}
