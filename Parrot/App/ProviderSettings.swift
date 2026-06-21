import Combine
import Foundation
import Security

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

enum ProviderSettingsError: LocalizedError {
    case invalidBaseURL
    case missingModel
    case missingAPIKey
    case authenticationFailed(String)
    case requestFailed(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid HTTPS Base URL."
        case .missingModel:
            return "Enter a model name before testing the provider."
        case .missingAPIKey:
            return "Enter an API Key or save one in Keychain before testing."
        case .authenticationFailed(let message):
            return "Authentication failed. \(message)"
        case .requestFailed(let message):
            return message
        case .unexpectedResponse:
            return "The provider returned an unexpected response."
        }
    }
}

final class ProviderSettingsStore: ObservableObject {
    @Published var selectedProviderID: String
    @Published var baseURLString: String
    @Published var modelName: String
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
        hasSavedAPIKey = (try? keychain.readAPIKey(providerID: settings.providerID)) != nil
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
        hasSavedAPIKey = (try? keychain.readAPIKey(providerID: providerID)) != nil
        statusMessage = nil
        isStatusError = false
    }

    func saveSettings() {
        do {
            try persistNonSecretSettings()
            try saveAPIKeyIfNeeded()
            statusMessage = hasSavedAPIKey
                ? "Settings saved. \(selectedPreset.name) API Key is stored in Keychain."
                : "Settings saved."
            isStatusError = false
        } catch {
            statusMessage = error.localizedDescription
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
            statusMessage = error.localizedDescription
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
            try saveAPIKeyIfNeeded()

            guard let apiKey = try keychain.readAPIKey(providerID: selectedProviderID), !apiKey.isEmpty else {
                throw ProviderSettingsError.missingAPIKey
            }

            let settings = currentSettings
            let client = OpenAICompatibleProviderClient(settings: settings, apiKey: apiKey)
            let responseSummary = try await client.testConnection()
            statusMessage = "Connection test succeeded. \(responseSummary)"
            isStatusError = false
        } catch {
            statusMessage = error.localizedDescription
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
        guard let data = try? JSONEncoder().encode(settings) else {
            throw ProviderSettingsError.requestFailed("Unable to save provider settings.")
        }
        userDefaults.set(data, forKey: LLMProviderSettings.storageKey)
    }

    private func saveAPIKeyIfNeeded() throws {
        let trimmedAPIKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            hasSavedAPIKey = (try? keychain.readAPIKey(providerID: selectedProviderID)) != nil
            return
        }

        try keychain.saveAPIKey(trimmedAPIKey, providerID: selectedProviderID)
        apiKeyInput = ""
        hasSavedAPIKey = true
    }
}

final class KeychainSecretStore {
    private let service: String
    private let accountPrefix = "openai-compatible-api-key"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.example.parrot") {
        self.service = service
    }

    func saveAPIKey(_ apiKey: String, providerID: String) throws {
        let data = Data(apiKey.utf8)
        var query = baseQuery(providerID: providerID)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemDelete(baseQuery(providerID: providerID) as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ProviderSettingsError.requestFailed(keychainMessage(for: status, fallback: "Unable to save API Key to Keychain."))
        }
    }

    func readAPIKey(providerID: String) throws -> String? {
        var query = baseQuery(providerID: providerID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw ProviderSettingsError.requestFailed(keychainMessage(for: status, fallback: "Unable to read API Key from Keychain."))
        }

        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey(providerID: String) throws {
        let status = SecItemDelete(baseQuery(providerID: providerID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProviderSettingsError.requestFailed(keychainMessage(for: status, fallback: "Unable to delete API Key from Keychain."))
        }
    }

    private func baseQuery(providerID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(accountPrefix)-\(providerID)"
        ]
    }

    private func keychainMessage(for status: OSStatus, fallback: String) -> String {
        SecCopyErrorMessageString(status, nil) as String? ?? fallback
    }
}

struct OpenAICompatibleProviderClient {
    let settings: LLMProviderSettings
    let apiKey: String

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

    func translate(_ text: String) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ProviderSettingsError.requestFailed("Enter text to translate.")
        }

        let targetLanguage = detectedTargetLanguage(for: trimmedText)
        let completion = try await makeChatCompletion(
            messages: [
                .init(
                    role: "system",
                    content: """
                    You are a professional translation assistant. Translate the user's text into \(targetLanguage).
                    Requirements:
                    1. Preserve paragraph structure.
                    2. Preserve code, variable names, links, product names, and proper nouns.
                    3. Do not add information that does not exist in the source text.
                    4. Output only the translation.
                    """
                ),
                .init(role: "user", content: trimmedText)
            ],
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
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ProviderSettingsError.requestFailed("Enter text to translate.")
        }

        let targetLanguage = detectedTargetLanguage(for: trimmedText)
        let messages = translationMessages(for: trimmedText, targetLanguage: targetLanguage)
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

        return response.error.message
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
        request.timeoutInterval = 25
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
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderSettingsError.unexpectedResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw mappedHTTPError(statusCode: httpResponse.statusCode, data: data)
            }

            return try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
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
        request.timeoutInterval = 25
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
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        let session = URLSession(configuration: configuration)

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProviderSettingsError.unexpectedResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw mappedHTTPError(statusCode: httpResponse.statusCode, data: try await data(from: bytes))
            }

            for try await line in bytes.lines {
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
        guard var components = URLComponents(string: settings.baseURLString),
              components.scheme == "https",
              components.host != nil
        else {
            throw ProviderSettingsError.invalidBaseURL
        }

        guard !settings.modelName.isEmpty else {
            throw ProviderSettingsError.missingModel
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/"))

        guard let url = components.url else {
            throw ProviderSettingsError.invalidBaseURL
        }

        return url
    }

    private func translationMessages(for text: String, targetLanguage: String) -> [OpenAIChatMessage] {
        [
            .init(
                role: "system",
                content: """
                You are a professional translation assistant. Translate the user's text into \(targetLanguage).
                Requirements:
                1. Preserve paragraph structure.
                2. Preserve code, variable names, links, product names, and proper nouns.
                3. Do not add information that does not exist in the source text.
                4. Output only the translation.
                """
            ),
            .init(role: "user", content: text)
        ]
    }

    private func detectedTargetLanguage(for text: String) -> String {
        let hasChinese = text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
        return hasChinese ? "English" : "Simplified Chinese"
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
