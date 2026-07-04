import Foundation

protocol TranslationStreamingProviding {
    func translateStreaming(
        _ text: String,
        preferences: TranslationLanguagePreferences,
        style: TranslationStyle,
        promptPreferences: TranslationPromptPreferences,
        glossaryEntries: [TranslationGlossaryEntry]?,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String
}

typealias TranslationClientFactory = (LLMProviderSettings, String) -> TranslationStreamingProviding

struct ProviderEndpointNormalizer {
    static func chatCompletionsURL(from baseURLString: String) throws -> URL {
        let trimmedURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmedURL),
              components.scheme == "https",
              components.host != nil
        else {
            throw ProviderSettingsError.invalidBaseURL
        }

        let pathComponents = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        let normalizedPathComponents: [String]

        if pathComponents.suffix(2).map({ $0.lowercased() }) == ["chat", "completions"] {
            normalizedPathComponents = pathComponents
        } else {
            normalizedPathComponents = pathComponents + ["chat", "completions"]
        }

        components.path = "/" + normalizedPathComponents.joined(separator: "/")

        guard let url = components.url else {
            throw ProviderSettingsError.invalidBaseURL
        }

        return url
    }
}

struct ProviderTimeoutPreference: Equatable {
    static let storageKey = "ProviderRequestTimeoutSeconds"
    static let defaultRequestTimeoutSeconds = 25.0
    static let minimumRequestTimeoutSeconds = 5.0
    static let maximumRequestTimeoutSeconds = 120.0

    var requestTimeoutSeconds: Double

    static let `default` = ProviderTimeoutPreference(requestTimeoutSeconds: defaultRequestTimeoutSeconds)

    static func loadSaved(from userDefaults: UserDefaults = .standard) -> ProviderTimeoutPreference {
        guard userDefaults.object(forKey: storageKey) != nil else {
            return .default
        }

        return ProviderTimeoutPreference(
            requestTimeoutSeconds: clamped(userDefaults.double(forKey: storageKey))
        )
    }

    func save(to userDefaults: UserDefaults = .standard) {
        userDefaults.set(Self.clamped(requestTimeoutSeconds), forKey: Self.storageKey)
    }

    var urlRequestTimeout: TimeInterval {
        Self.clamped(requestTimeoutSeconds)
    }

    var standardResourceTimeout: TimeInterval {
        max(Self.clamped(requestTimeoutSeconds) + 5, 30)
    }

    var streamingResourceTimeout: TimeInterval {
        max(Self.clamped(requestTimeoutSeconds) + 20, 45)
    }

    static func clamped(_ value: Double) -> Double {
        min(max(value, minimumRequestTimeoutSeconds), maximumRequestTimeoutSeconds)
    }
}

enum ProviderErrorSanitizer {
    static func safeMessage(_ message: String, redactedSecrets: [String] = [], maxLength: Int = 240) -> String {
        var safe = message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for secret in redactedSecrets where !secret.isEmpty {
            safe = safe.replacingOccurrences(of: secret, with: "[redacted]")
        }

        let redactionPatterns: [(pattern: String, replacement: String)] = [
            (#"(?i)(authorization:\s*bearer\s+)[A-Za-z0-9_\-\.=]{8,}"#, "$1[redacted]"),
            (#"(?i)(bearer\s+)[A-Za-z0-9_\-\.=]{8,}"#, "$1[redacted]"),
            (#"sk-[A-Za-z0-9_\-]{8,}"#, "[redacted]"),
            (#"(?i)(api[_ -]?key[=: ]+)[A-Za-z0-9_\-\.]{8,}"#, "$1[redacted]"),
            (#"(?i)(token[=: ]+)[A-Za-z0-9_\-\.]{8,}"#, "$1[redacted]"),
            (#"(?<![A-Za-z0-9])[A-Za-z0-9_\-]{40,}(?![A-Za-z0-9])"#, "[redacted]")
        ]

        for pattern in redactionPatterns {
            safe = safe.replacingOccurrences(
                of: pattern.pattern,
                with: pattern.replacement,
                options: .regularExpression
            )
        }

        if safe.count > maxLength {
            safe = String(safe.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        return safe
    }
}
