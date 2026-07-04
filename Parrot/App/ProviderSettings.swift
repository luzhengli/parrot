import Combine
import Foundation
import LocalAuthentication
import Security

enum TranslationStyle: String, CaseIterable, Codable, Identifiable {
    case accurate
    case natural
    case professional
    case concise

    var id: String { rawValue }

    static let storageKey = "TranslationStylePreference"
    static let `default`: TranslationStyle = .accurate

    var displayName: String {
        switch self {
        case .accurate:
            return "Accurate"
        case .natural:
            return "Natural"
        case .professional:
            return "Professional"
        case .concise:
            return "Concise"
        }
    }

    var promptName: String {
        switch self {
        case .accurate:
            return "Accurate"
        case .natural:
            return "Natural"
        case .professional:
            return "Professional"
        case .concise:
            return "Concise"
        }
    }

    var detail: String {
        switch self {
        case .accurate:
            return "Faithful to the original meaning for reading, debugging, and reference material."
        case .natural:
            return "Smoother everyday wording for chat and casual writing."
        case .professional:
            return "Formal, consistent wording for docs, email, and product material."
        case .concise:
            return "Compressed wording for quick understanding and summary-like translation."
        }
    }

    var promptInstruction: String {
        switch self {
        case .accurate:
            return "Stay faithful to the original meaning and keep nuance."
        case .natural:
            return "Use fluent, natural wording while preserving the original meaning."
        case .professional:
            return "Use formal, professional wording and keep terminology consistent."
        case .concise:
            return "Use concise wording and remove redundancy without losing key meaning."
        }
    }

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> TranslationStyle {
        guard let rawValue = userDefaults.string(forKey: storageKey),
              let style = TranslationStyle(rawValue: rawValue)
        else {
            return .default
        }

        return style
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(rawValue, forKey: Self.storageKey)
    }
}

struct TranslationPromptPreferences: Codable, Equatable {
    var isCustomPromptEnabled: Bool
    var customPromptTemplate: String

    static let storageKey = "TranslationPromptPreferences"
    static let defaults = TranslationPromptPreferences(isCustomPromptEnabled: false, customPromptTemplate: defaultPromptTemplate)
    static let requiredVariables = ["{target_language}", "{text}"]
    static let supportedVariables = ["{source_language}", "{target_language}", "{style}", "{glossary}", "{text}"]

    static let defaultPromptTemplate = """
    System:
    You are a professional translation assistant. Translate the user's text into {target_language}.
    Source language: {source_language}.
    Target language: {target_language}.
    Translation style: {style}.
    Requirements:
    1. Preserve paragraph structure.
    2. Preserve code, variable names, links, product names, and proper nouns.
    3. Follow the selected translation style.
    4. Follow matched glossary entries when provided.
    5. Do not add information that does not exist in the source text.
    6. Output only the translation.

    Glossary:
    {glossary}

    User:
    {text}
    """

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> TranslationPromptPreferences {
        guard let data = userDefaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(TranslationPromptPreferences.self, from: data)
        else {
            return .defaults
        }

        return preferences
    }

    func save(to userDefaults: UserDefaults = .standard) throws {
        if isCustomPromptEnabled, let validationMessage = Self.validationMessage(for: customPromptTemplate) {
            throw ProviderSettingsError.requestFailed(validationMessage)
        }

        guard let data = try? JSONEncoder().encode(self) else {
            throw ProviderSettingsError.requestFailed("Unable to save custom Prompt settings.")
        }

        userDefaults.set(data, forKey: Self.storageKey)
    }

    static func restoreDefault(to userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: storageKey)
    }

    static func validationMessage(for template: String) -> String? {
        let trimmedTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTemplate.isEmpty else {
            return "Custom Prompt cannot be empty."
        }

        let missingVariables = requiredVariables.filter { !trimmedTemplate.contains($0) }
        guard missingVariables.isEmpty else {
            return "Custom Prompt must include \(missingVariables.joined(separator: " and "))."
        }

        return nil
    }

    var activeCustomTemplate: String? {
        guard isCustomPromptEnabled,
              Self.validationMessage(for: customPromptTemplate) == nil
        else {
            return nil
        }

        return customPromptTemplate
    }
}

struct TranslationGlossaryEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var sourceTerm: String
    var targetTerm: String
    var targetLanguage: TranslationLanguage?
    var context: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        sourceTerm: String = "",
        targetTerm: String = "",
        targetLanguage: TranslationLanguage? = nil,
        context: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.sourceTerm = sourceTerm
        self.targetTerm = targetTerm
        self.targetLanguage = targetLanguage
        self.context = context
        self.isEnabled = isEnabled
    }

    var trimmedSourceTerm: String {
        sourceTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTargetTerm: String {
        targetTerm.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedContext: String {
        context.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranslationGlossary {
    static let emptyPromptText = "No matched glossary entries."

    static func validationMessage(
        for entry: TranslationGlossaryEntry,
        existingEntries: [TranslationGlossaryEntry],
        editingID: UUID? = nil
    ) -> String? {
        guard !entry.trimmedSourceTerm.isEmpty else {
            return "Source term is required."
        }

        guard !entry.trimmedTargetTerm.isEmpty else {
            return "Target term is required."
        }

        if hasDuplicate(entry: entry, in: existingEntries, ignoring: editingID) {
            return "A glossary entry with the same source term and target language already exists."
        }

        return nil
    }

    static func matchedEntries(
        for text: String,
        targetLanguage: TranslationLanguage,
        entries: [TranslationGlossaryEntry]
    ) -> [TranslationGlossaryEntry] {
        let sourceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else {
            return []
        }

        return entries.filter { entry in
            guard entry.isEnabled,
                  !entry.trimmedSourceTerm.isEmpty,
                  entry.targetLanguage == nil || entry.targetLanguage == targetLanguage
            else {
                return false
            }

            return sourceText.range(
                of: entry.trimmedSourceTerm,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    static func promptText(for entries: [TranslationGlossaryEntry]) -> String {
        guard !entries.isEmpty else {
            return emptyPromptText
        }

        return entries.map { entry in
            var line = "- \(entry.trimmedSourceTerm) -> \(entry.trimmedTargetTerm)"
            if let targetLanguage = entry.targetLanguage {
                line += " (target: \(targetLanguage.promptName))"
            }
            if !entry.trimmedContext.isEmpty {
                line += "; context: \(entry.trimmedContext)"
            }
            return line
        }
        .joined(separator: "\n")
    }

    static func hasDuplicate(
        entry: TranslationGlossaryEntry,
        in entries: [TranslationGlossaryEntry],
        ignoring editingID: UUID? = nil
    ) -> Bool {
        let sourceKey = normalized(entry.trimmedSourceTerm)
        let targetLanguage = entry.targetLanguage
        guard !sourceKey.isEmpty else {
            return false
        }

        return entries.contains { existingEntry in
            if let editingID, existingEntry.id == editingID {
                return false
            }

            return normalized(existingEntry.trimmedSourceTerm) == sourceKey
                && existingEntry.targetLanguage == targetLanguage
        }
    }

    private static func normalized(_ term: String) -> String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

@MainActor
final class TranslationGlossaryStore: ObservableObject {
    static let shared = TranslationGlossaryStore()

    @Published private(set) var entries: [TranslationGlossaryEntry]
    @Published private(set) var statusMessage: String?
    @Published private(set) var isStatusError = false

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultGlossaryFileURL()
        entries = Self.loadEntries(from: self.fileURL)
    }

    func save(entry: TranslationGlossaryEntry, editingID: UUID? = nil) -> Bool {
        guard let validationMessage = TranslationGlossary.validationMessage(
            for: entry,
            existingEntries: entries,
            editingID: editingID
        ) else {
            var updatedEntry = entry
            updatedEntry.sourceTerm = entry.trimmedSourceTerm
            updatedEntry.targetTerm = entry.trimmedTargetTerm
            updatedEntry.context = entry.trimmedContext

            if let editingID, let index = entries.firstIndex(where: { $0.id == editingID }) {
                updatedEntry.id = editingID
                entries[index] = updatedEntry
                statusMessage = "Glossary entry updated."
            } else {
                entries.insert(updatedEntry, at: 0)
                statusMessage = "Glossary entry added."
            }

            isStatusError = false
            persistEntries()
            return true
        }

        statusMessage = validationMessage
        isStatusError = true
        return false
    }

    func setEnabled(_ entry: TranslationGlossaryEntry, isEnabled: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }

        entries[index].isEnabled = isEnabled
        statusMessage = isEnabled ? "Glossary entry enabled." : "Glossary entry disabled."
        isStatusError = false
        persistEntries()
    }

    func delete(_ entry: TranslationGlossaryEntry) {
        entries.removeAll { $0.id == entry.id }
        statusMessage = "Glossary entry deleted."
        isStatusError = false
        persistEntries()
    }

    func filteredEntries(searchText: String) -> [TranslationGlossaryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return entries
        }

        return entries.filter { entry in
            entry.sourceTerm.localizedCaseInsensitiveContains(query)
                || entry.targetTerm.localizedCaseInsensitiveContains(query)
        }
    }

    private func persistEntries() {
        do {
            try Self.saveEntries(entries, to: fileURL)
        } catch {
            statusMessage = "Unable to save glossary: \(error.localizedDescription)"
            isStatusError = true
        }
    }

    nonisolated static func loadEntries(from fileURL: URL) -> [TranslationGlossaryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([TranslationGlossaryEntry].self, from: data)
        else {
            return []
        }

        return entries
    }

    nonisolated static func saveEntries(_ entries: [TranslationGlossaryEntry], to fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: fileURL, options: .atomic)
    }

    nonisolated static func defaultGlossaryFileURL() -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("Parrot", isDirectory: true)
            .appendingPathComponent("terminology-glossary.json")
    }
}

enum TranslationLanguage: String, CaseIterable, Codable, Identifiable {
    case chinese
    case english
    case japanese
    case korean
    case french
    case spanish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese:
            return "Chinese"
        case .english:
            return "English"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .french:
            return "French"
        case .spanish:
            return "Spanish"
        }
    }

    var promptName: String {
        switch self {
        case .chinese:
            return "Simplified Chinese"
        case .english:
            return "English"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .french:
            return "French"
        case .spanish:
            return "Spanish"
        }
    }
}

enum TranslationSourceSelection: String, CaseIterable, Codable, Identifiable {
    case auto
    case chinese
    case english
    case japanese
    case korean
    case french
    case spanish

    var id: String { rawValue }

    var displayName: String {
        explicitLanguage?.displayName ?? "Auto"
    }

    var explicitLanguage: TranslationLanguage? {
        TranslationLanguage(rawValue: rawValue)
    }

    init(language: TranslationLanguage) {
        self = TranslationSourceSelection(rawValue: language.rawValue) ?? .auto
    }
}

enum TranslationTargetSelection: String, CaseIterable, Codable, Identifiable {
    case autoOpposite
    case chinese
    case english
    case japanese
    case korean
    case french
    case spanish

    var id: String { rawValue }

    var displayName: String {
        explicitLanguage?.displayName ?? "Auto Opposite"
    }

    var explicitLanguage: TranslationLanguage? {
        TranslationLanguage(rawValue: rawValue)
    }

    init(language: TranslationLanguage) {
        self = TranslationTargetSelection(rawValue: language.rawValue) ?? .autoOpposite
    }
}

struct TranslationLanguagePreferences: Codable, Equatable {
    var sourceLanguage: TranslationSourceSelection
    var targetLanguage: TranslationTargetSelection

    static let storageKey = "TranslationLanguagePreferences"
    static let defaults = TranslationLanguagePreferences(sourceLanguage: .auto, targetLanguage: .autoOpposite)

    var validationMessage: String? {
        guard let source = sourceLanguage.explicitLanguage,
              let target = targetLanguage.explicitLanguage,
              source == target
        else {
            return nil
        }

        return "Source and target languages must be different."
    }

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> TranslationLanguagePreferences {
        guard let data = userDefaults.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(TranslationLanguagePreferences.self, from: data)
        else {
            return .defaults
        }

        return preferences
    }

    func save(to userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }

        userDefaults.set(data, forKey: Self.storageKey)
    }

    mutating func swapLanguages(recentDetectedSource: TranslationLanguage?) {
        if let source = sourceLanguage.explicitLanguage,
           let target = targetLanguage.explicitLanguage {
            sourceLanguage = TranslationSourceSelection(language: target)
            targetLanguage = TranslationTargetSelection(language: source)
            return
        }

        if sourceLanguage == .auto,
           let target = targetLanguage.explicitLanguage {
            sourceLanguage = TranslationSourceSelection(language: target)
            targetLanguage = .autoOpposite
            return
        }

        if targetLanguage == .autoOpposite {
            let effectiveSource = sourceLanguage.explicitLanguage ?? recentDetectedSource
            guard let effectiveSource else {
                return
            }

            sourceLanguage = TranslationSourceSelection(language: Self.oppositeLanguage(for: effectiveSource))
            targetLanguage = TranslationTargetSelection(language: effectiveSource)
        }
    }

    static func oppositeLanguage(for language: TranslationLanguage) -> TranslationLanguage {
        switch language {
        case .chinese:
            return .english
        case .english:
            return .chinese
        case .japanese, .korean, .french, .spanish:
            return .chinese
        }
    }

}

struct TranslationLanguageResolution: Equatable {
    let sourceLanguage: TranslationLanguage
    let targetLanguage: TranslationLanguage
    let sourcePromptName: String
    let targetPromptName: String
}

enum TranslationLanguageResolver {
    static func resolve(
        text: String,
        preferences: TranslationLanguagePreferences
    ) throws -> TranslationLanguageResolution {
        if let validationMessage = preferences.validationMessage {
            throw ProviderSettingsError.requestFailed(validationMessage)
        }

        let detectedSource = detectSourceLanguage(in: text)
        let sourceLanguage = preferences.sourceLanguage.explicitLanguage ?? detectedSource
        let targetLanguage = preferences.targetLanguage.explicitLanguage ?? TranslationLanguagePreferences.oppositeLanguage(for: sourceLanguage)

        return TranslationLanguageResolution(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            sourcePromptName: preferences.sourceLanguage.explicitLanguage == nil ? "Auto-detected \(sourceLanguage.promptName)" : sourceLanguage.promptName,
            targetPromptName: targetLanguage.promptName
        )
    }

    static func detectSourceLanguage(in text: String) -> TranslationLanguage {
        let scalars = text.unicodeScalars

        if scalars.contains(where: { (0x4E00...0x9FFF).contains(Int($0.value)) }) {
            return .chinese
        }

        if scalars.contains(where: { (0x3040...0x30FF).contains(Int($0.value)) }) {
            return .japanese
        }

        if scalars.contains(where: { (0xAC00...0xD7AF).contains(Int($0.value)) }) {
            return .korean
        }

        return .english
    }
}

struct LLMProviderSettings: Codable, Equatable {
    var providerID: String
    var baseURLString: String
    var modelName: String
    static let storageKey = "LLMProviderSettings"

    static let defaults = LLMProviderSettings(
        providerID: LLMProviderPreset.deepSeek.id,
        baseURLString: LLMProviderPreset.deepSeek.baseURLString,
        modelName: LLMProviderPreset.deepSeek.modelName
    )

    init(providerID: String, baseURLString: String, modelName: String) {
        self.providerID = providerID
        self.baseURLString = baseURLString
        self.modelName = modelName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID) ?? LLMProviderPreset.custom.id
        baseURLString = try container.decode(String.self, forKey: .baseURLString)
        modelName = try container.decode(String.self, forKey: .modelName)
    }

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> LLMProviderSettings {
        guard let data = userDefaults.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(LLMProviderSettings.self, from: data)
        else {
            return .defaults
        }

        return settings
    }
}

struct LLMProviderPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let baseURLString: String
    let modelName: String
    let detail: String
    let locksEndpoint: Bool

    static let deepSeek = LLMProviderPreset(
        id: "deepseek",
        name: "DeepSeek",
        baseURLString: "https://api.deepseek.com",
        modelName: "deepseek-v4-flash",
        detail: "Recommended default. OpenAI-compatible DeepSeek endpoint.",
        locksEndpoint: true
    )

    static let glm = LLMProviderPreset(
        id: "glm",
        name: "GLM",
        baseURLString: "https://open.bigmodel.cn/api/paas/v4",
        modelName: "glm-4.7",
        detail: "Zhipu GLM OpenAI-compatible endpoint.",
        locksEndpoint: true
    )

    static let openAI = LLMProviderPreset(
        id: "openai",
        name: "OpenAI",
        baseURLString: "https://api.openai.com/v1",
        modelName: "gpt-4o-mini",
        detail: "OpenAI-compatible default endpoint.",
        locksEndpoint: true
    )

    static let custom = LLMProviderPreset(
        id: "custom",
        name: "Custom",
        baseURLString: "",
        modelName: "",
        detail: "Use any OpenAI-compatible provider.",
        locksEndpoint: false
    )

    static let presets = [deepSeek, glm, openAI, custom]

    static func preset(for id: String) -> LLMProviderPreset {
        presets.first { $0.id == id } ?? custom
    }
}

enum ParrotAboutInfo {
    static let releaseChannel = "Unsigned RC"
    static let macOSRequirement = "macOS 14.0 or later"
    static let releaseNotesURL = URL(string: "https://github.com/luzhengli/parrot/releases")!
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/luzhengli/parrot/releases/latest")!
    static let feedbackURL = URL(string: "https://github.com/luzhengli/parrot/issues/new")!
}

struct ParrotSemanticVersion: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?

    init?(_ string: String) {
        let rawTrimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = rawTrimmed.lowercased().hasPrefix("v")
            ? String(rawTrimmed.dropFirst())
            : rawTrimmed
        let versionAndPrerelease = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numericParts = versionAndPrerelease[0]
            .split(separator: ".")
            .compactMap { Int($0) }

        guard numericParts.count >= 2 else {
            return nil
        }

        major = numericParts[0]
        minor = numericParts[1]
        patch = numericParts.count > 2 ? numericParts[2] : 0
        prerelease = versionAndPrerelease.count > 1 ? String(versionAndPrerelease[1]) : nil
    }

    static func < (lhs: ParrotSemanticVersion, rhs: ParrotSemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case (let lhsPrerelease?, let rhsPrerelease?):
            return lhsPrerelease.localizedStandardCompare(rhsPrerelease) == .orderedAscending
        }
    }
}

struct ParrotReleaseInfo: Equatable {
    let version: String
    let releaseDate: String
    let releaseNotesURL: URL
    let downloadURL: URL
    let isPrerelease: Bool
    let summary: String
    let checksumSummary: String?
}

enum ParrotUpdateCheckStatus: Equatable {
    case idle
    case checking
    case upToDate(message: String)
    case updateAvailable(ParrotReleaseInfo, message: String)
    case unableToCheck(message: String)
}

@MainActor
final class ParrotUpdateChecker: ObservableObject {
    typealias DataLoader = (URLRequest) async throws -> (Data, URLResponse)

    @Published private(set) var status: ParrotUpdateCheckStatus = .idle

    private let dataLoader: DataLoader

    init(dataLoader: @escaping DataLoader = { request in
        try await URLSession.shared.data(for: request)
    }) {
        self.dataLoader = dataLoader
    }

    func checkForUpdates(
        currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
        currentBuild: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    ) async {
        status = .checking

        do {
            var request = URLRequest(url: ParrotAboutInfo.latestReleaseAPIURL)
            request.httpMethod = "GET"
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Parrot/\(currentVersion) (\(ParrotAboutInfo.releaseChannel))", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await dataLoader(request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                status = .unableToCheck(message: "GitHub Releases returned HTTP \(httpResponse.statusCode). Try again later.")
                return
            }

            let release = try Self.parseLatestRelease(from: data)
            status = Self.status(
                currentVersion: currentVersion,
                currentBuild: currentBuild,
                latestRelease: release
            )
        } catch {
            status = .unableToCheck(message: "Unable to check GitHub Releases: \(error.localizedDescription)")
        }
    }

    static func parseLatestRelease(from data: Data) throws -> ParrotReleaseInfo {
        let response = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        guard let version = response.normalizedVersion,
              ParrotSemanticVersion(version) != nil,
              let releaseNotesURL = URL(string: response.htmlURL)
        else {
            throw ProviderSettingsError.requestFailed("The update feed did not include a valid release version or URL.")
        }

        let downloadAsset = response.assets.first { asset in
            asset.name.localizedCaseInsensitiveContains(".dmg")
                || asset.name.localizedCaseInsensitiveContains(".zip")
        }
        let checksumAsset = response.assets.first { asset in
            asset.name.localizedCaseInsensitiveContains("sha256")
                || asset.name.localizedCaseInsensitiveContains("checksum")
        }
        let downloadURL = downloadAsset.flatMap { URL(string: $0.browserDownloadURL) } ?? releaseNotesURL
        let summary = response.body?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .prefix(4)
            .joined(separator: "\n")
            ?? "See release notes for details."
        let checksumSummary = checksumAsset == nil
            ? nil
            : "Checksum metadata is available in \(checksumAsset?.name ?? "the release assets")."

        return ParrotReleaseInfo(
            version: version,
            releaseDate: response.publishedAt ?? "unknown",
            releaseNotesURL: releaseNotesURL,
            downloadURL: downloadURL,
            isPrerelease: response.prerelease,
            summary: summary.isEmpty ? "See release notes for details." : summary,
            checksumSummary: checksumSummary
        )
    }

    static func status(
        currentVersion: String,
        currentBuild: String,
        latestRelease: ParrotReleaseInfo
    ) -> ParrotUpdateCheckStatus {
        guard let current = ParrotSemanticVersion(currentVersion),
              let latest = ParrotSemanticVersion(latestRelease.version)
        else {
            return .unableToCheck(message: "Unable to compare current version \(currentVersion) with latest version \(latestRelease.version).")
        }

        if latest > current {
            let message = """
            Version \(latestRelease.version) is available. Current version: \(currentVersion) (\(currentBuild)).
            \(latestRelease.summary)
            Manual download only for \(ParrotAboutInfo.releaseChannel); Parrot will not install updates automatically.
            \(latestRelease.checksumSummary ?? "No checksum or signature metadata was found in the release feed. Verify release assets manually before replacing the app.")
            """
            return .updateAvailable(latestRelease, message: message)
        }

        if current > latest {
            return .upToDate(message: "This local build (\(currentVersion), build \(currentBuild)) is newer than the latest GitHub release \(latestRelease.version). No downgrade is recommended.")
        }

        return .upToDate(message: "Parrot \(currentVersion) (build \(currentBuild)) matches the latest GitHub release.")
    }

    static func versionInfoText(
        currentVersion: String,
        currentBuild: String,
        status: ParrotUpdateCheckStatus
    ) -> String {
        var lines = [
            "Parrot Version Info",
            "Current Version: \(currentVersion)",
            "Current Build: \(currentBuild)",
            "Release Channel: \(ParrotAboutInfo.releaseChannel)"
        ]

        if case .updateAvailable(let release, _) = status {
            lines.append("Latest Version: \(release.version)")
            lines.append("Release Date: \(release.releaseDate)")
            lines.append("Release Notes: \(release.releaseNotesURL.absoluteString)")
            lines.append("Download: \(release.downloadURL.absoluteString)")
            lines.append("Prerelease: \(release.isPrerelease ? "yes" : "no")")
            lines.append(release.checksumSummary ?? "Checksum Metadata: not found in feed")
        }

        return lines.joined(separator: "\n")
    }

    private struct GitHubReleaseResponse: Decodable {
        let tagName: String
        let name: String?
        let htmlURL: String
        let publishedAt: String?
        let body: String?
        let prerelease: Bool
        let assets: [GitHubReleaseAsset]

        var normalizedVersion: String? {
            let rawVersion = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawVersion.isEmpty else {
                return nil
            }
            return rawVersion.lowercased().hasPrefix("v")
                ? String(rawVersion.dropFirst())
                : rawVersion
        }

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case htmlURL = "html_url"
            case publishedAt = "published_at"
            case body
            case prerelease
            case assets
        }
    }

    private struct GitHubReleaseAsset: Decodable {
        let name: String
        let browserDownloadURL: String

        private enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}

struct ParrotDiagnosticsSummary: Equatable {
    var appVersion: String
    var buildNumber: String
    var bundleIdentifier: String
    var macOSVersion: String
    var providerPresetID: String
    var releaseChannel: String
    var screenRecordingPermission: String
    var featureFlags: [String]

    static func current(
        bundle: Bundle = .main,
        settings: LLMProviderSettings = .loadSaved(),
        screenRecordingPermissionGranted: Bool? = nil
    ) -> ParrotDiagnosticsSummary {
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown"
        let permissionStatus: String
        if let screenRecordingPermissionGranted {
            permissionStatus = screenRecordingPermissionGranted ? "granted" : "not granted"
        } else {
            permissionStatus = "unknown"
        }

        return ParrotDiagnosticsSummary(
            appVersion: appVersion,
            buildNumber: buildNumber,
            bundleIdentifier: bundleIdentifier,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            providerPresetID: settings.providerID,
            releaseChannel: ParrotAboutInfo.releaseChannel,
            screenRecordingPermission: permissionStatus,
            featureFlags: [
                "local-ocr",
                "keychain-api-key",
                "text-only-history",
                "custom-shortcuts",
                "long-text-segmentation",
                "unsigned-release"
            ]
        )
    }

    var text: String {
        [
            "Parrot Diagnostics",
            "Version: \(appVersion)",
            "Build: \(buildNumber)",
            "Bundle Identifier: \(bundleIdentifier)",
            "macOS: \(macOSVersion)",
            "Provider Preset ID: \(providerPresetID)",
            "Release Channel: \(releaseChannel)",
            "Screen Recording Permission: \(screenRecordingPermission)",
            "Feature Flags: \(featureFlags.joined(separator: ", "))"
        ].joined(separator: "\n")
    }
}

enum ParrotOnboardingStatus: String, Equatable {
    case notStarted
    case skipped
    case completed

    var displayName: String {
        switch self {
        case .notStarted:
            return "Not started"
        case .skipped:
            return "Skipped for this version"
        case .completed:
            return "Complete"
        }
    }
}

struct ParrotOnboardingState: Equatable {
    static let currentSchemaVersion = 1
    static let statusKey = "ParrotOnboardingStatus"
    static let schemaVersionKey = "ParrotOnboardingSchemaVersion"

    var status: ParrotOnboardingStatus
    var schemaVersion: Int

    static func load(from userDefaults: UserDefaults = .standard) -> ParrotOnboardingState {
        let rawStatus = userDefaults.string(forKey: statusKey)
        let status = rawStatus.flatMap(ParrotOnboardingStatus.init(rawValue:)) ?? .notStarted
        let schemaVersion = userDefaults.object(forKey: schemaVersionKey) == nil
            ? currentSchemaVersion
            : userDefaults.integer(forKey: schemaVersionKey)
        return ParrotOnboardingState(status: status, schemaVersion: schemaVersion)
    }

    static func shouldPresentOnLaunch(
        providerConfigurationIsValid: Bool,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard providerConfigurationIsValid else {
            return true
        }

        let state = load(from: userDefaults)
        guard state.schemaVersion == currentSchemaVersion else {
            return true
        }

        return state.status == .notStarted
    }

    static func markSkipped(in userDefaults: UserDefaults = .standard) -> ParrotOnboardingState {
        save(status: .skipped, to: userDefaults)
    }

    static func markCompleted(in userDefaults: UserDefaults = .standard) -> ParrotOnboardingState {
        save(status: .completed, to: userDefaults)
    }

    static func reset(in userDefaults: UserDefaults = .standard) -> ParrotOnboardingState {
        userDefaults.removeObject(forKey: statusKey)
        userDefaults.removeObject(forKey: schemaVersionKey)
        return load(from: userDefaults)
    }

    static func save(status: ParrotOnboardingStatus, to userDefaults: UserDefaults = .standard) -> ParrotOnboardingState {
        userDefaults.set(status.rawValue, forKey: statusKey)
        userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
        return load(from: userDefaults)
    }
}

struct ParrotLaunchHubPreferences: Equatable {
    static let showOnStartupKey = "ParrotShowLaunchHubOnStartup"

    var showOnStartup: Bool

    static func load(from userDefaults: UserDefaults = .standard) -> ParrotLaunchHubPreferences {
        let showOnStartup = userDefaults.object(forKey: showOnStartupKey) == nil
            ? true
            : userDefaults.bool(forKey: showOnStartupKey)
        return ParrotLaunchHubPreferences(showOnStartup: showOnStartup)
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(showOnStartup, forKey: Self.showOnStartupKey)
    }

    @discardableResult
    static func setShowOnStartup(
        _ showOnStartup: Bool,
        in userDefaults: UserDefaults = .standard
    ) -> ParrotLaunchHubPreferences {
        let preferences = ParrotLaunchHubPreferences(showOnStartup: showOnStartup)
        preferences.save(to: userDefaults)
        return preferences
    }
}

struct ParrotDockIconPreferences: Equatable {
    static let showDockIconKey = "ParrotShowDockIcon"

    var showDockIcon: Bool

    static func load(from userDefaults: UserDefaults = .standard) -> ParrotDockIconPreferences {
        ParrotDockIconPreferences(showDockIcon: userDefaults.bool(forKey: showDockIconKey))
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(showDockIcon, forKey: Self.showDockIconKey)
    }

    @discardableResult
    static func setShowDockIcon(
        _ showDockIcon: Bool,
        in userDefaults: UserDefaults = .standard
    ) -> ParrotDockIconPreferences {
        let preferences = ParrotDockIconPreferences(showDockIcon: showDockIcon)
        preferences.save(to: userDefaults)
        return preferences
    }
}

enum ParrotStartupDestination: Equatable {
    case setup
    case launchHub
    case none
}

struct ParrotStartupPresentation {
    static func destination(
        providerConfigurationIsValid: Bool,
        userDefaults: UserDefaults = .standard
    ) -> ParrotStartupDestination {
        if ParrotOnboardingState.shouldPresentOnLaunch(
            providerConfigurationIsValid: providerConfigurationIsValid,
            userDefaults: userDefaults
        ) {
            return .setup
        }

        let launchPreferences = ParrotLaunchHubPreferences.load(from: userDefaults)
        return launchPreferences.showOnStartup ? .launchHub : .none
    }
}

enum ProviderSettingsError: LocalizedError {
    case invalidBaseURL
    case missingModel
    case missingAPIKey
    case apiKeyRequiresReentry
    case authenticationFailed(String)
    case requestFailed(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid HTTPS Base URL."
        case .missingModel:
            return "Enter a model name before saving or testing the provider."
        case .missingAPIKey:
            return "Enter an API Key or save one in Keychain before testing."
        case .apiKeyRequiresReentry:
            return "The saved API Key cannot be read without showing a system Keychain password prompt."
        case .authenticationFailed(let message):
            return "Authentication failed. \(message)"
        case .requestFailed(let message):
            return message
        case .unexpectedResponse:
            return "The provider returned an unexpected response."
        }
    }
}

enum UserFacingErrorRecoveryAction: Equatable {
    case openSetup
    case openModelSettings
    case retry

    var title: String {
        switch self {
        case .openSetup:
            return "Open Setup"
        case .openModelSettings:
            return "Open Model Settings"
        case .retry:
            return "Retry"
        }
    }

    var systemImageName: String {
        switch self {
        case .openSetup:
            return "checklist"
        case .openModelSettings:
            return "slider.horizontal.3"
        case .retry:
            return "arrow.clockwise"
        }
    }
}

struct UserFacingErrorPresentation {
    let title: String
    let message: String
    let recoverySuggestion: String
    let recoveryAction: UserFacingErrorRecoveryAction

    init(error: Error) {
        if let providerError = error as? ProviderSettingsError {
            self = Self(providerError: providerError)
        } else {
            title = "Something went wrong"
            message = error.localizedDescription
            recoverySuggestion = "Try again. If the problem continues, check Settings and your network connection."
            recoveryAction = .retry
        }
    }

    init(providerError: ProviderSettingsError) {
        switch providerError {
        case .invalidBaseURL:
            title = "Invalid Base URL"
            message = "The configured provider URL is not a valid HTTPS endpoint."
            recoverySuggestion = "Open Settings, enter the provider Base URL, then retry."
            recoveryAction = .openModelSettings
        case .missingModel:
            title = "Model name required"
            message = "A model must be configured before Parrot can request a translation."
            recoverySuggestion = "Open Settings, enter a model name, then retry."
            recoveryAction = .openModelSettings
        case .missingAPIKey:
            title = "API Key required"
            message = "No API Key is saved for the selected provider."
            recoverySuggestion = "Open Settings, save the API Key to Keychain, then retry."
            recoveryAction = .openSetup
        case .apiKeyRequiresReentry:
            title = "API Key needs to be saved again"
            message = "macOS requires a Keychain password prompt before this debug build can read the previously saved API Key."
            recoverySuggestion = "Open Settings and re-enter the API Key. Parrot will not show a system Keychain prompt during translation."
            recoveryAction = .openSetup
        case .authenticationFailed(let providerMessage):
            let safeProviderMessage = Self.safeMessage(providerMessage)
            title = "Authentication failed"
            message = safeProviderMessage.isEmpty
                ? "The provider rejected the saved API Key or account access."
                : "The provider rejected the request: \(safeProviderMessage)"
            recoverySuggestion = "Open Settings, replace the Keychain API Key or confirm account access, then retry."
            recoveryAction = .openModelSettings
        case .requestFailed(let providerMessage):
            let safeProviderMessage = Self.safeMessage(providerMessage)
            if safeProviderMessage.localizedCaseInsensitiveContains("timed out") {
                title = "Request timed out"
                message = safeProviderMessage
                recoverySuggestion = "Check the provider status or network connection, then use Retry."
                recoveryAction = .retry
            } else if safeProviderMessage.localizedCaseInsensitiveContains("network request failed") {
                title = "Network request failed"
                message = safeProviderMessage
                recoverySuggestion = "Check the network or Base URL, then use Retry."
                recoveryAction = .retry
            } else {
                title = "Provider request failed"
                message = safeProviderMessage
                recoverySuggestion = "Check Settings and provider compatibility, then retry."
                recoveryAction = .openModelSettings
            }
        case .unexpectedResponse:
            title = "Unsupported provider response"
            message = "The provider returned a response Parrot could not read."
            recoverySuggestion = "Check that the Base URL uses an OpenAI-compatible chat completions endpoint, then retry."
            recoveryAction = .openModelSettings
        }
    }

    var combinedMessage: String {
        "\(title). \(message) \(recoverySuggestion)"
    }

    private static func safeMessage(_ message: String) -> String {
        ProviderErrorSanitizer.safeMessage(message)
    }
}

extension Error {
    var userFacingMessage: String {
        UserFacingErrorPresentation(error: self).combinedMessage
    }
}

final class ProviderSettingsStore: ObservableObject {
    @Published var selectedProviderID: String
    @Published var baseURLString: String
    @Published var modelName: String
    @Published var requestTimeoutSeconds: Double
    @Published var apiKeyInput = ""
    @Published private(set) var hasSavedAPIKey: Bool
    @Published private(set) var statusMessage: String?
    @Published private(set) var isTesting = false
    @Published private(set) var isStatusError = false

    private let userDefaults: UserDefaults
    private let keychain: KeychainSecretStore

    init(
        userDefaults: UserDefaults = .standard,
        keychain: KeychainSecretStore = KeychainSecretStore()
    ) {
        self.userDefaults = userDefaults
        self.keychain = keychain

        let settings = LLMProviderSettings.loadSaved(from: userDefaults)
        selectedProviderID = settings.providerID
        baseURLString = settings.baseURLString
        modelName = settings.modelName
        requestTimeoutSeconds = ProviderTimeoutPreference.loadSaved(from: userDefaults).requestTimeoutSeconds
        hasSavedAPIKey = keychain.hasSavedAPIKeyRecord(providerID: settings.providerID)
    }

    var selectedPreset: LLMProviderPreset {
        LLMProviderPreset.preset(for: selectedProviderID)
    }

    func selectProvider(_ providerID: String) {
        selectedProviderID = providerID
        let preset = LLMProviderPreset.preset(for: providerID)

        if preset != .custom {
            baseURLString = preset.baseURLString
            modelName = preset.modelName
        }

        apiKeyInput = ""
        hasSavedAPIKey = keychain.hasSavedAPIKeyRecord(providerID: providerID)
        statusMessage = nil
        isStatusError = false
    }

    func saveSettings() {
        do {
            try persistNonSecretSettings()
            _ = try saveAPIKeyIfNeeded()
            statusMessage = hasSavedAPIKey
                ? "Settings saved. \(selectedPreset.name) API Key is stored in Keychain."
                : "Settings saved."
            isStatusError = false
        } catch {
            statusMessage = error.userFacingMessage
            isStatusError = true
        }
    }

    func deleteAPIKey() {
        do {
            try keychain.deleteAPIKey(providerID: selectedProviderID)
            apiKeyInput = ""
            hasSavedAPIKey = false
            statusMessage = "API Key deleted from Keychain for \(selectedPreset.name)."
            isStatusError = false
        } catch {
            statusMessage = error.userFacingMessage
            isStatusError = true
        }
    }

    @MainActor
    func testConnection() async {
        isTesting = true
        statusMessage = "Testing provider connection..."
        isStatusError = false

        do {
            try persistNonSecretSettings()
            let freshlySavedAPIKey = try saveAPIKeyIfNeeded()

            let apiKey = try freshlySavedAPIKey ?? keychain.readAPIKey(providerID: selectedProviderID)
            guard let apiKey, !apiKey.isEmpty else {
                throw ProviderSettingsError.missingAPIKey
            }

            let settings = currentSettings
            let client = OpenAICompatibleProviderClient(settings: settings, apiKey: apiKey)
            let responseSummary = try await client.testConnection()
            statusMessage = "Connection test succeeded. \(responseSummary)"
            isStatusError = false
        } catch {
            statusMessage = error.userFacingMessage
            isStatusError = true
        }

        isTesting = false
    }

    private var currentSettings: LLMProviderSettings {
        LLMProviderSettings(
            providerID: selectedProviderID,
            baseURLString: baseURLString.trimmingCharacters(in: .whitespacesAndNewlines),
            modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func persistNonSecretSettings() throws {
        let settings = currentSettings
        try validateNonSecretSettings(settings)
        guard let data = try? JSONEncoder().encode(settings) else {
            throw ProviderSettingsError.requestFailed("Unable to save provider settings.")
        }
        userDefaults.set(data, forKey: LLMProviderSettings.storageKey)
        ProviderTimeoutPreference(requestTimeoutSeconds: requestTimeoutSeconds).save(to: userDefaults)
    }

    private func validateNonSecretSettings(_ settings: LLMProviderSettings) throws {
        _ = try ProviderEndpointNormalizer.chatCompletionsURL(from: settings.baseURLString)
        guard !settings.modelName.isEmpty else {
            throw ProviderSettingsError.missingModel
        }
    }

    private func saveAPIKeyIfNeeded() throws -> String? {
        let trimmedAPIKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            hasSavedAPIKey = keychain.hasSavedAPIKeyRecord(providerID: selectedProviderID)
            return nil
        }

        try keychain.saveAPIKey(trimmedAPIKey, providerID: selectedProviderID)
        apiKeyInput = ""
        hasSavedAPIKey = true
        return trimmedAPIKey
    }
}

protocol KeychainAccessing {
    func add(_ query: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
    func copyMatching(_ query: [String: Any], item: inout CFTypeRef?) -> OSStatus
    func errorMessage(for status: OSStatus) -> String?
}

struct SystemKeychainAccess: KeychainAccessing {
    func add(_ query: [String: Any]) -> OSStatus {
        SecItemAdd(query as CFDictionary, nil)
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }

    func copyMatching(_ query: [String: Any], item: inout CFTypeRef?) -> OSStatus {
        SecItemCopyMatching(query as CFDictionary, &item)
    }

    func errorMessage(for status: OSStatus) -> String? {
        SecCopyErrorMessageString(status, nil) as String?
    }
}

final class KeychainSecretStore {
    private struct CacheKey: Hashable {
        let service: String
        let providerID: String
    }

    private static var cachedAPIKeys: [CacheKey: String] = [:]
    private static let cacheLock = NSLock()
    private static let savedProviderIDsKey = "SavedAPIKeyProviderIDs"

    static func clearProcessCacheForTesting() {
        cacheLock.lock()
        cachedAPIKeys.removeAll()
        cacheLock.unlock()
    }

    private let service: String
    private let userDefaults: UserDefaults
    private let keychainAccess: KeychainAccessing
    private let accountPrefix = "openai-compatible-api-key"

    init(
        service: String = Bundle.main.bundleIdentifier ?? "com.example.parrot",
        userDefaults: UserDefaults = .standard,
        keychainAccess: KeychainAccessing = SystemKeychainAccess()
    ) {
        self.service = service
        self.userDefaults = userDefaults
        self.keychainAccess = keychainAccess
    }

    func saveAPIKey(_ apiKey: String, providerID: String) throws {
        let data = Data(apiKey.utf8)
        var query = baseQuery(providerID: providerID)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        _ = keychainAccess.delete(baseQuery(providerID: providerID))
        let status = keychainAccess.add(query)
        guard status == errSecSuccess else {
            throw ProviderSettingsError.requestFailed(keychainMessage(for: status, fallback: "Unable to save API Key to Keychain."))
        }

        cacheAPIKey(apiKey, providerID: providerID)
        markAPIKeyRecordSaved(providerID: providerID)
    }

    func readAPIKey(providerID: String) throws -> String? {
        guard hasSavedAPIKeyRecord(providerID: providerID) else {
            return nil
        }

        if let cachedAPIKey = cachedAPIKey(providerID: providerID) {
            return cachedAPIKey
        }

        var query = baseQuery(providerID: providerID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        // LAContext alone does not suppress older Keychain ACL prompts for ad-hoc debug builds.
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail

        var item: CFTypeRef?
        let status = keychainAccess.copyMatching(query, item: &item)
        if status == errSecItemNotFound {
            clearCachedAPIKey(providerID: providerID)
            markAPIKeyRecordMissing(providerID: providerID)
            return nil
        }

        if status == errSecInteractionNotAllowed || status == errSecAuthFailed {
            clearCachedAPIKey(providerID: providerID)
            markAPIKeyRecordMissing(providerID: providerID)
            throw ProviderSettingsError.apiKeyRequiresReentry
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw ProviderSettingsError.requestFailed(keychainMessage(for: status, fallback: "Unable to read API Key from Keychain."))
        }

        let apiKey = String(data: data, encoding: .utf8)
        if let apiKey {
            cacheAPIKey(apiKey, providerID: providerID)
        }
        return apiKey
    }

    func hasSavedAPIKeyRecord(providerID: String) -> Bool {
        savedProviderIDs().contains(providerID)
    }

    func deleteAPIKey(providerID: String) throws {
        let status = keychainAccess.delete(baseQuery(providerID: providerID))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProviderSettingsError.requestFailed(keychainMessage(for: status, fallback: "Unable to delete API Key from Keychain."))
        }
        clearCachedAPIKey(providerID: providerID)
        markAPIKeyRecordMissing(providerID: providerID)
    }

    private func baseQuery(providerID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(accountPrefix)-\(providerID)"
        ]
    }

    private func keychainMessage(for status: OSStatus, fallback: String) -> String {
        keychainAccess.errorMessage(for: status) ?? fallback
    }

    private func cachedAPIKey(providerID: String) -> String? {
        let key = CacheKey(service: service, providerID: providerID)
        Self.cacheLock.lock()
        defer { Self.cacheLock.unlock() }
        return Self.cachedAPIKeys[key]
    }

    private func cacheAPIKey(_ apiKey: String, providerID: String) {
        let key = CacheKey(service: service, providerID: providerID)
        Self.cacheLock.lock()
        Self.cachedAPIKeys[key] = apiKey
        Self.cacheLock.unlock()
    }

    private func clearCachedAPIKey(providerID: String) {
        let key = CacheKey(service: service, providerID: providerID)
        Self.cacheLock.lock()
        Self.cachedAPIKeys.removeValue(forKey: key)
        Self.cacheLock.unlock()
    }

    private func savedProviderIDs() -> Set<String> {
        Set(userDefaults.stringArray(forKey: Self.savedProviderIDsKey) ?? [])
    }

    private func markAPIKeyRecordSaved(providerID: String) {
        var providerIDs = savedProviderIDs()
        providerIDs.insert(providerID)
        userDefaults.set(Array(providerIDs).sorted(), forKey: Self.savedProviderIDsKey)
    }

    private func markAPIKeyRecordMissing(providerID: String) {
        var providerIDs = savedProviderIDs()
        providerIDs.remove(providerID)
        userDefaults.set(Array(providerIDs).sorted(), forKey: Self.savedProviderIDsKey)
    }
}

struct OpenAICompatibleProviderClient: TranslationStreamingProviding {
    let settings: LLMProviderSettings
    let apiKey: String
    let timeoutPreference: ProviderTimeoutPreference

    init(
        settings: LLMProviderSettings,
        apiKey: String,
        timeoutPreference: ProviderTimeoutPreference = .loadSaved()
    ) {
        self.settings = settings
        self.apiKey = apiKey
        self.timeoutPreference = timeoutPreference
    }

    func testConnection() async throws -> String {
        let completion = try await makeChatCompletion(
            messages: [
                .init(role: "system", content: "You are testing an API connection. Reply with OK only."),
                .init(role: "user", content: "Reply with OK.")
            ],
            maxTokens: 8,
            timeoutMessage: "The connection test timed out. Check the Base URL or network connection.",
            failurePrefix: "Connection test failed"
        )
        let reply = completion.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return reply?.isEmpty == false ? "Provider replied: \(reply!)." : "Provider accepted the test request."
    }

    func translate(
        _ text: String,
        preferences: TranslationLanguagePreferences = .defaults,
        style: TranslationStyle = TranslationStyle.loadSaved(),
        promptPreferences: TranslationPromptPreferences = TranslationPromptPreferences.loadSaved(),
        glossaryEntries: [TranslationGlossaryEntry]? = nil
    ) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ProviderSettingsError.requestFailed("Enter text to translate.")
        }

        let messages = try translationMessages(
            for: trimmedText,
            preferences: preferences,
            style: style,
            promptPreferences: promptPreferences,
            glossaryEntries: glossaryEntries
        )
        let completion = try await makeChatCompletion(
            messages: messages,
            maxTokens: 2_000,
            timeoutMessage: "Translation timed out. Check the provider or network connection.",
            failurePrefix: "Translation failed"
        )
        let translatedText = completion.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !translatedText.isEmpty else {
            throw ProviderSettingsError.unexpectedResponse
        }

        return translatedText
    }

    func translateStreaming(
        _ text: String,
        preferences: TranslationLanguagePreferences = .defaults,
        style: TranslationStyle = TranslationStyle.loadSaved(),
        promptPreferences: TranslationPromptPreferences = TranslationPromptPreferences.loadSaved(),
        glossaryEntries: [TranslationGlossaryEntry]? = nil,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ProviderSettingsError.requestFailed("Enter text to translate.")
        }

        let messages = try translationMessages(
            for: trimmedText,
            preferences: preferences,
            style: style,
            promptPreferences: promptPreferences,
            glossaryEntries: glossaryEntries
        )
        var finalTranslation = ""

        try await makeChatCompletionStream(
            messages: messages,
            maxTokens: 2_000,
            timeoutMessage: "Translation timed out. Check the provider or network connection."
        ) { delta in
            finalTranslation += delta
            await onDelta(delta)
        }

        finalTranslation = finalTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalTranslation.isEmpty else {
            throw ProviderSettingsError.unexpectedResponse
        }

        return finalTranslation
    }

    private func mappedHTTPError(statusCode: Int, data: Data) -> ProviderSettingsError {
        let message = apiErrorMessage(from: data)

        if statusCode == 401 || statusCode == 403 {
            return .authenticationFailed(message)
        }

        return .requestFailed("Provider returned HTTP \(statusCode). \(message)")
    }

    private func apiErrorMessage(from data: Data) -> String {
        guard let response = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) else {
            return "Check Base URL, model name, and provider compatibility."
        }

        return sanitizedProviderMessage(response.error.message)
    }

    private func sanitizedProviderMessage(_ message: String) -> String {
        ProviderErrorSanitizer.safeMessage(message, redactedSecrets: [apiKey], maxLength: 220)
    }

    private func makeChatCompletion(
        messages: [OpenAIChatMessage],
        maxTokens: Int,
        timeoutMessage: String,
        failurePrefix: String
    ) async throws -> OpenAIChatCompletionResponse {
        let url = try chatCompletionsURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutPreference.urlRequestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAIChatCompletionRequest(
            model: settings.modelName,
            messages: messages,
            maxTokens: maxTokens,
            temperature: 0.2,
            stream: false
        ))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutPreference.urlRequestTimeout
        configuration.timeoutIntervalForResource = timeoutPreference.standardResourceTimeout
        let session = URLSession(configuration: configuration)

        do {
            try Task.checkCancellation()
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderSettingsError.unexpectedResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw mappedHTTPError(statusCode: httpResponse.statusCode, data: data)
            }

            return try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ProviderSettingsError {
            throw error
        } catch let error as URLError {
            if error.code == .timedOut {
                throw ProviderSettingsError.requestFailed(timeoutMessage)
            }
            throw ProviderSettingsError.requestFailed("Network request failed: \(error.localizedDescription)")
        } catch {
            throw ProviderSettingsError.requestFailed("\(failurePrefix): \(error.localizedDescription)")
        }
    }

    private func makeChatCompletionStream(
        messages: [OpenAIChatMessage],
        maxTokens: Int,
        timeoutMessage: String,
        onDelta: @escaping (String) async -> Void
    ) async throws {
        let url = try chatCompletionsURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutPreference.urlRequestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(OpenAIChatCompletionRequest(
            model: settings.modelName,
            messages: messages,
            maxTokens: maxTokens,
            temperature: 0.2,
            stream: true
        ))

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutPreference.urlRequestTimeout
        configuration.timeoutIntervalForResource = timeoutPreference.streamingResourceTimeout
        let session = URLSession(configuration: configuration)

        do {
            try Task.checkCancellation()
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderSettingsError.unexpectedResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw mappedHTTPError(statusCode: httpResponse.statusCode, data: try await data(from: bytes))
            }

            for try await line in bytes.lines {
                try Task.checkCancellation()
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedLine.hasPrefix("data:") else {
                    continue
                }

                let payload = trimmedLine.dropFirst("data:".count).trimmingCharacters(in: .whitespacesAndNewlines)
                if payload == "[DONE]" {
                    break
                }

                guard let data = payload.data(using: .utf8),
                      let chunk = try? JSONDecoder().decode(OpenAIChatCompletionStreamChunk.self, from: data)
                else {
                    continue
                }

                for choice in chunk.choices {
                    if let content = choice.delta.content, !content.isEmpty {
                        await onDelta(content)
                    }
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ProviderSettingsError {
            throw error
        } catch let error as URLError {
            if error.code == .timedOut {
                throw ProviderSettingsError.requestFailed(timeoutMessage)
            }
            throw ProviderSettingsError.requestFailed("Network request failed: \(error.localizedDescription)")
        } catch {
            throw ProviderSettingsError.requestFailed("Translation failed: \(error.localizedDescription)")
        }
    }

    private func chatCompletionsURL() throws -> URL {
        guard !settings.modelName.isEmpty else {
            throw ProviderSettingsError.missingModel
        }

        return try ProviderEndpointNormalizer.chatCompletionsURL(from: settings.baseURLString)
    }

    func translationDebugPrompt(
        for text: String,
        preferences: TranslationLanguagePreferences = .defaults,
        style: TranslationStyle = TranslationStyle.loadSaved(),
        promptPreferences: TranslationPromptPreferences = TranslationPromptPreferences.loadSaved(),
        glossaryEntries: [TranslationGlossaryEntry] = []
    ) throws -> String {
        let resolution = try TranslationLanguageResolver.resolve(text: text, preferences: preferences)
        let matchedGlossaryText = TranslationGlossary.promptText(
            for: TranslationGlossary.matchedEntries(
                for: text,
                targetLanguage: resolution.targetLanguage,
                entries: glossaryEntries
            )
        )
        return translationPrompt(
            text: text,
            languageResolution: resolution,
            style: style,
            promptPreferences: promptPreferences,
            glossaryText: matchedGlossaryText
        )
    }

    private func translationMessages(
        for text: String,
        preferences: TranslationLanguagePreferences,
        style: TranslationStyle,
        promptPreferences: TranslationPromptPreferences,
        glossaryEntries: [TranslationGlossaryEntry]?
    ) throws -> [OpenAIChatMessage] {
        let resolution = try TranslationLanguageResolver.resolve(text: text, preferences: preferences)
        let entries = glossaryEntries ?? TranslationGlossaryStore.loadEntries(from: TranslationGlossaryStore.defaultGlossaryFileURL())
        let matchedGlossaryText = TranslationGlossary.promptText(
            for: TranslationGlossary.matchedEntries(
                for: text,
                targetLanguage: resolution.targetLanguage,
                entries: entries
            )
        )
        if promptPreferences.activeCustomTemplate != nil {
            return [
                .init(
                    role: "system",
                    content: translationPrompt(
                        text: text,
                        languageResolution: resolution,
                        style: style,
                        promptPreferences: promptPreferences,
                        glossaryText: matchedGlossaryText
                    )
                ),
                .init(role: "user", content: "Translate the text included in the active Prompt template.")
            ]
        }

        return [
            .init(
                role: "system",
                content: translationSystemPrompt(
                    languageResolution: resolution,
                    style: style,
                    glossaryText: matchedGlossaryText
                )
            ),
            .init(role: "user", content: text)
        ]
    }

    private func translationPrompt(
        text: String,
        languageResolution: TranslationLanguageResolution,
        style: TranslationStyle,
        promptPreferences: TranslationPromptPreferences,
        glossaryText: String
    ) -> String {
        guard let customTemplate = promptPreferences.activeCustomTemplate else {
            return translationSystemPrompt(
                languageResolution: languageResolution,
                style: style,
                glossaryText: glossaryText
            )
        }

        return renderPromptTemplate(
            customTemplate,
            text: text,
            languageResolution: languageResolution,
            style: style,
            glossaryText: glossaryText
        )
    }

    private func translationSystemPrompt(
        languageResolution: TranslationLanguageResolution,
        style: TranslationStyle,
        glossaryText: String
    ) -> String {
        """
        You are a professional translation assistant. Translate the user's text into \(languageResolution.targetPromptName).
        Source language: \(languageResolution.sourcePromptName).
        Target language: \(languageResolution.targetPromptName).
        Translation style: \(style.promptName).
        Requirements:
        1. Preserve paragraph structure.
        2. Preserve code, variable names, links, product names, and proper nouns.
        3. \(style.promptInstruction)
        4. Follow matched glossary entries when provided.
        5. Do not add information that does not exist in the source text.
        6. Output only the translation.

        Glossary:
        \(glossaryText)
        """
    }

    private func renderPromptTemplate(
        _ template: String,
        text: String,
        languageResolution: TranslationLanguageResolution,
        style: TranslationStyle,
        glossaryText: String
    ) -> String {
        template
            .replacingOccurrences(of: "{source_language}", with: languageResolution.sourcePromptName)
            .replacingOccurrences(of: "{target_language}", with: languageResolution.targetPromptName)
            .replacingOccurrences(of: "{style}", with: style.promptName)
            .replacingOccurrences(of: "{glossary}", with: glossaryText)
            .replacingOccurrences(of: "{text}", with: text)
    }

    private func data(from bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
        }
        return data
    }
}

private struct OpenAIChatCompletionRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let maxTokens: Int
    let temperature: Double
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case stream
    }
}

private struct OpenAIChatMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenAIChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct OpenAIChatCompletionStreamChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta

        struct Delta: Decodable {
            let content: String?
        }
    }
}

private struct OpenAIErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}
