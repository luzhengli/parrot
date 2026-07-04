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
struct ProviderEndpointTimeoutE2E {
    static func main() {
        do {
            try run()
            print("provider-endpoint-timeout-e2e passed")
        } catch {
            fputs("provider-endpoint-timeout-e2e failed: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        let rootURL = try ProviderEndpointNormalizer.chatCompletionsURL(from: "https://api.example.com")
        try require(rootURL.absoluteString == "https://api.example.com/chat/completions", "Root provider URL should normalize to chat completions.")

        let v1URL = try ProviderEndpointNormalizer.chatCompletionsURL(from: "https://api.example.com/v1/")
        try require(v1URL.absoluteString == "https://api.example.com/v1/chat/completions", "/v1 provider URL should normalize to chat completions.")

        let fullURL = try ProviderEndpointNormalizer.chatCompletionsURL(from: "https://api.example.com/v1/chat/completions")
        try require(fullURL.absoluteString == "https://api.example.com/v1/chat/completions", "Full chat completions URL should not be duplicated.")

        do {
            _ = try ProviderEndpointNormalizer.chatCompletionsURL(from: "http://api.example.com/v1")
            throw E2EFailure.assertion("Non-HTTPS provider URL should be rejected.")
        } catch ProviderSettingsError.invalidBaseURL {
        }

        let suiteName = "provider-timeout-e2e-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw E2EFailure.assertion("Unable to create isolated defaults.")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        try require(
            ProviderTimeoutPreference.loadSaved(from: defaults).requestTimeoutSeconds == 25,
            "Default timeout should preserve the existing 25 second request behavior."
        )
        ProviderTimeoutPreference(requestTimeoutSeconds: 60).save(to: defaults)
        let savedTimeout = ProviderTimeoutPreference.loadSaved(from: defaults)
        try require(savedTimeout.urlRequestTimeout == 60, "Saved timeout should affect URLRequest timeout.")
        try require(savedTimeout.standardResourceTimeout == 65, "Standard resource timeout should scale from the saved timeout.")
        try require(savedTimeout.streamingResourceTimeout == 80, "Streaming resource timeout should scale from the saved timeout.")

        ProviderTimeoutPreference(requestTimeoutSeconds: 1_000).save(to: defaults)
        try require(
            ProviderTimeoutPreference.loadSaved(from: defaults).requestTimeoutSeconds == ProviderTimeoutPreference.maximumRequestTimeoutSeconds,
            "Timeout should be clamped to the maximum supported value."
        )

        let unsafeMessage = "HTTP 401 Authorization: Bearer sk-testsecret1234567890 token=abcdef1234567890 api_key=secret-key-1234567890"
        let safeMessage = ProviderErrorSanitizer.safeMessage(unsafeMessage, redactedSecrets: ["secret-key-1234567890"])
        try require(!safeMessage.contains("sk-testsecret"), "sk-style keys should be redacted.")
        try require(!safeMessage.contains("abcdef1234567890"), "token-like values should be redacted.")
        try require(!safeMessage.contains("secret-key-1234567890"), "explicit secrets should be redacted.")
        try require(safeMessage.contains("HTTP 401"), "HTTP status summary should be preserved.")
    }
}
