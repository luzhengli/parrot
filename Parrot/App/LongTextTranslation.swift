import Foundation

struct TranslationSegment: Equatable, Identifiable {
    let index: Int
    let text: String

    var id: Int { index }
}

enum TranslationLengthPlan: Equatable {
    case single
    case segmented([TranslationSegment])
    case requiresConfirmation(characterCount: Int, segments: [TranslationSegment])
}

enum LongTextTranslationPlanner {
    static let singleRequestCharacterLimit = 2_500
    static let automaticSegmentedCharacterLimit = 8_000
    static let maxSegmentCharacterCount = 1_800

    static func plan(for text: String, allowLargeText: Bool = false) -> TranslationLengthPlan {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let characterCount = trimmedText.count

        guard characterCount > singleRequestCharacterLimit else {
            return .single
        }

        let segments = segment(trimmedText, maxCharacters: maxSegmentCharacterCount)
        guard characterCount <= automaticSegmentedCharacterLimit || allowLargeText else {
            return .requiresConfirmation(characterCount: characterCount, segments: segments)
        }

        return .segmented(segments)
    }

    static func segment(_ text: String, maxCharacters: Int = maxSegmentCharacterCount) -> [TranslationSegment] {
        let blocks = paragraphBlocks(in: text.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { splitOversizedBlock($0, maxCharacters: maxCharacters) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        var segments: [String] = []
        var current = ""

        for block in blocks {
            if current.isEmpty {
                current = block
                continue
            }

            let candidate = current + "\n\n" + block
            if candidate.count <= maxCharacters {
                current = candidate
            } else {
                segments.append(current)
                current = block
            }
        }

        if !current.isEmpty {
            segments.append(current)
        }

        return segments.enumerated().map { offset, text in
            TranslationSegment(index: offset, text: text)
        }
    }

    private static func paragraphBlocks(in text: String) -> [String] {
        var blocks: [String] = []
        var currentLines: [String] = []
        var isInsideCodeFence = false

        for line in text.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let isFence = trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")

            if isFence {
                currentLines.append(line)
                isInsideCodeFence.toggle()
                continue
            }

            if trimmedLine.isEmpty, !isInsideCodeFence {
                if !currentLines.isEmpty {
                    blocks.append(currentLines.joined(separator: "\n"))
                    currentLines.removeAll()
                }
                continue
            }

            currentLines.append(line)
        }

        if !currentLines.isEmpty {
            blocks.append(currentLines.joined(separator: "\n"))
        }

        return blocks
    }

    private static func splitOversizedBlock(_ block: String, maxCharacters: Int) -> [String] {
        guard block.count > maxCharacters else {
            return [block]
        }

        if block.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
            || block.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("~~~") {
            return splitLongLine(block, maxCharacters: maxCharacters)
        }

        var chunks: [String] = []
        var current = ""

        for line in block.components(separatedBy: .newlines) {
            let lineChunks = line.count > maxCharacters ? splitLongLine(line, maxCharacters: maxCharacters) : [line]
            for lineChunk in lineChunks {
                if current.isEmpty {
                    current = lineChunk
                    continue
                }

                let separator = current.contains("\n") ? "\n" : " "
                let candidate = current + separator + lineChunk
                if candidate.count <= maxCharacters {
                    current = candidate
                } else {
                    chunks.append(current)
                    current = lineChunk
                }
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }

        return chunks
    }

    private static func splitLongLine(_ line: String, maxCharacters: Int) -> [String] {
        var chunks: [String] = []
        var remaining = line.trimmingCharacters(in: .whitespacesAndNewlines)

        while remaining.count > maxCharacters {
            let upperBound = remaining.index(remaining.startIndex, offsetBy: maxCharacters)
            let searchRange = remaining.startIndex..<upperBound
            let minimumBreakOffset = max(1, Int(Double(maxCharacters) * 0.6))
            let minimumBreakIndex = remaining.index(remaining.startIndex, offsetBy: minimumBreakOffset)
            let breakIndex = remaining[searchRange]
                .lastIndex(where: { $0.isWhitespace })
                .flatMap { $0 >= minimumBreakIndex ? $0 : nil }
                ?? upperBound

            let chunk = String(remaining[..<breakIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }

            remaining = String(remaining[breakIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !remaining.isEmpty {
            chunks.append(remaining)
        }

        return chunks
    }
}
