import AppKit
import Foundation
import SwiftUI

struct TranslationHistoryRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceType: String
    let createdAt: Date
}

@MainActor
final class TranslationHistoryStore: ObservableObject {
    static let shared = TranslationHistoryStore()

    static let enabledStorageKey = "TranslationHistoryEnabled"

    @Published private(set) var records: [TranslationHistoryRecord]
    @Published private(set) var isHistoryEnabled: Bool

    private let userDefaults: UserDefaults
    private let fileURL: URL
    private let maxRecordCount: Int

    init(
        userDefaults: UserDefaults = .standard,
        fileURL: URL? = nil,
        maxRecordCount: Int = 50
    ) {
        self.userDefaults = userDefaults
        self.fileURL = fileURL ?? Self.defaultHistoryFileURL()
        self.maxRecordCount = maxRecordCount
        isHistoryEnabled = userDefaults.object(forKey: Self.enabledStorageKey) as? Bool ?? true
        records = Self.loadRecords(from: self.fileURL)
    }

    func setHistoryEnabled(_ isEnabled: Bool) {
        isHistoryEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: Self.enabledStorageKey)
    }

    func addRecord(sourceText: String, translatedText: String, sourceType: String) {
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isHistoryEnabled, !source.isEmpty, !translation.isEmpty else {
            return
        }

        let record = TranslationHistoryRecord(
            id: UUID(),
            sourceText: source,
            translatedText: translation,
            sourceType: sourceType,
            createdAt: Date()
        )
        records.insert(record, at: 0)

        if records.count > maxRecordCount {
            records = Array(records.prefix(maxRecordCount))
        }

        saveRecords()
    }

    func copyTranslation(_ record: TranslationHistoryRecord) {
        copyToPasteboard(record.translatedText)
    }

    func copyOriginal(_ record: TranslationHistoryRecord) {
        copyToPasteboard(record.sourceText)
    }

    func clear() {
        records = []
        saveRecords()
    }

    private func saveRecords() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder.historyEncoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to save translation history: %@", error.localizedDescription)
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func loadRecords(from fileURL: URL) -> [TranslationHistoryRecord] {
        guard let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder.historyDecoder.decode([TranslationHistoryRecord].self, from: data)
        else {
            return []
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    private static func defaultHistoryFileURL() -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("Parrot", isDirectory: true)
            .appendingPathComponent("translation-history.json")
    }
}

private extension JSONEncoder {
    static var historyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var historyDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct TranslationHistoryView: View {
    @ObservedObject private var store = TranslationHistoryStore.shared
    @State private var selectedRecord: TranslationHistoryRecord?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if store.records.isEmpty {
                emptyState
            } else {
                historyList
            }

            footer
        }
        .padding(24)
        .frame(width: 720, height: 540)
        .onExitCommand(perform: onClose)
        .sheet(item: $selectedRecord) { record in
            TranslationHistoryDetailView(
                record: record,
                onCopyTranslation: { store.copyTranslation(record) },
                onCopyOriginal: { store.copyOriginal(record) }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tint)

                Text("Translation History")
                    .font(.title2.bold())
            }

            Text(store.isHistoryEnabled
                 ? "Recent translations are saved locally on this Mac."
                 : "History is disabled. Existing records remain available until you clear them.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No translation history yet.")
                .font(.headline)

            Text("Successful quick text and screenshot translations will appear here while history is enabled.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(store.records) { record in
                    HistoryRecordRow(
                        record: record,
                        onOpenDetails: { selectedRecord = record },
                        onCopyTranslation: { store.copyTranslation(record) },
                        onCopyOriginal: { store.copyOriginal(record) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var footer: some View {
        HStack {
            Button("Clear History", role: .destructive) {
                store.clear()
            }
            .disabled(store.records.isEmpty)

            Spacer()

            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }
}

private struct HistoryRecordRow: View {
    let record: TranslationHistoryRecord
    let onOpenDetails: () -> Void
    let onCopyTranslation: () -> Void
    let onCopyOriginal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(record.sourceType, systemImage: iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                textColumn(title: "Original", text: record.sourceText)
                textColumn(title: "Translation", text: record.translatedText)
            }

            HStack {
                Button("View Details", action: onOpenDetails)
                Button("Copy Translation", action: onCopyTranslation)
                Button("Copy Original", action: onCopyOriginal)
            }
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onOpenDetails)
    }

    private var iconName: String {
        record.sourceType == "Screenshot" ? "text.viewfinder" : "text.cursor"
    }

    private func textColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.system(size: 13))
                .lineLimit(4)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68, alignment: .topLeading)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct TranslationHistoryDetailView: View {
    let record: TranslationHistoryRecord
    let onCopyTranslation: () -> Void
    let onCopyOriginal: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(record.sourceType, systemImage: iconName)
                        .font(.callout.weight(.semibold))

                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            HStack(alignment: .top, spacing: 14) {
                detailColumn(title: "Original", text: record.sourceText)
                detailColumn(title: "Translation", text: record.translatedText)
            }

            HStack {
                Button("Copy Translation", action: onCopyTranslation)
                Button("Copy Original", action: onCopyOriginal)
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 760, height: 520)
    }

    private var iconName: String {
        record.sourceType == "Screenshot" ? "text.viewfinder" : "text.cursor"
    }

    private func detailColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ScrollView {
                Text(text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(height: 360)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }
}
