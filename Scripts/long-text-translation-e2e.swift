import Foundation

enum E2EFailure: Error, CustomStringConvertible {
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
        throw E2EFailure.assertion(message)
    }
}

@main
struct LongTextTranslationE2E {
    static func main() {
        do {
            try run()
            print("long-text-translation-e2e passed")
        } catch {
            fputs("long-text-translation-e2e failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        let shortText = "Hello Parrot"
        try require(LongTextTranslationPlanner.plan(for: shortText) == .single, "Short text should keep the single-request path.")

        let markdownBlock = """
        ## Notes

        Visit https://example.com/path?query=value before changing `providerBaseURL`.

        ```swift
        let providerBaseURL = "https://api.example.com/v1"
        print(providerBaseURL)
        ```
        """
        let repeatedParagraphs = (0..<6)
            .map { index in "\(markdownBlock)\nParagraph \(index): " + String(repeating: "translation context ", count: 40) }
            .joined(separator: "\n\n")

        guard case .segmented(let segments) = LongTextTranslationPlanner.plan(for: repeatedParagraphs) else {
            throw E2EFailure.assertion("2000-8000 character text should enter segmented mode.")
        }

        try require(segments.count > 1, "Segmented mode should produce multiple segments.")
        try require(segments.allSatisfy { $0.text.count <= LongTextTranslationPlanner.maxSegmentCharacterCount }, "Segments should respect the max segment size.")
        try require(
            segments.contains { $0.text.contains("```swift") && $0.text.contains("providerBaseURL") },
            "Markdown code blocks should be preserved inside a segment when possible."
        )
        try require(
            segments.contains { $0.text.contains("https://example.com/path?query=value") },
            "URLs should remain intact when paragraph-sized content fits the segment limit."
        )

        let veryLongText = String(repeating: "Long text risk. ", count: 700)
        guard case .requiresConfirmation(let count, let largeSegments) = LongTextTranslationPlanner.plan(for: veryLongText) else {
            throw E2EFailure.assertion("Over-8000 character text should require confirmation.")
        }
        try require(count > LongTextTranslationPlanner.automaticSegmentedCharacterLimit, "Confirmation should report the large character count.")
        try require(!largeSegments.isEmpty, "Confirmation should still prepare a deterministic segment plan.")

        guard case .segmented = LongTextTranslationPlanner.plan(for: veryLongText, allowLargeText: true) else {
            throw E2EFailure.assertion("Confirmed large text should be allowed into segmented mode.")
        }
    }
}
