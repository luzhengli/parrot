import Foundation

enum ScreenCaptureAccessGateE2EFailure: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case .assertion(let message):
            return message
        }
    }
}

func require(
    _ actual: ScreenCaptureAccessGate.Outcome,
    equals expected: ScreenCaptureAccessGate.Outcome,
    _ message: String
) throws {
    guard actual == expected else {
        throw ScreenCaptureAccessGateE2EFailure.assertion("\(message) Expected \(expected), got \(actual).")
    }
}

@main
struct ScreenCaptureAccessGateE2E {
    static func main() throws {
        var deniedGate = ScreenCaptureAccessGate()
        try require(
            deniedGate.evaluate(preflight: { false }, request: { false }),
            equals: .requestPresented,
            "First missing-permission attempt should suppress app-level error while macOS presents its prompt."
        )
        try require(
            deniedGate.evaluate(preflight: { false }, request: { false }),
            equals: .deniedAfterRequest,
            "Second missing-permission attempt should surface Parrot guidance instead of silently returning."
        )

        var grantedAfterPromptGate = ScreenCaptureAccessGate()
        try require(
            grantedAfterPromptGate.evaluate(preflight: { false }, request: { false }),
            equals: .requestPresented,
            "Initial request should be tracked."
        )
        try require(
            grantedAfterPromptGate.evaluate(preflight: { true }, request: { false }),
            equals: .granted,
            "Granting Screen Recording permission should allow selection on the next attempt."
        )
        try require(
            grantedAfterPromptGate.evaluate(preflight: { false }, request: { false }),
            equals: .requestPresented,
            "A later TCC reset should be treated as a fresh macOS prompt opportunity."
        )

        var immediateGrantGate = ScreenCaptureAccessGate()
        try require(
            immediateGrantGate.evaluate(preflight: { false }, request: { true }),
            equals: .granted,
            "A request that grants access immediately should proceed."
        )

        print("screen-capture-access-gate-e2e passed")
    }
}
