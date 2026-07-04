import Foundation

struct TranslationRequestID: Hashable, CustomStringConvertible {
    private let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    var description: String {
        rawValue.uuidString
    }
}

@MainActor
final class TranslationRequestCoordinator {
    private(set) var activeRequestID: TranslationRequestID?
    private var activeTask: Task<Void, Never>?

    var hasActiveRequest: Bool {
        activeRequestID != nil
    }

    @discardableResult
    func beginRequest() -> TranslationRequestID {
        cancelActiveRequest()
        let requestID = TranslationRequestID()
        activeRequestID = requestID
        return requestID
    }

    func attachTask(_ task: Task<Void, Never>, to requestID: TranslationRequestID) {
        guard isActive(requestID) else {
            task.cancel()
            return
        }

        activeTask = task
    }

    func cancelActiveRequest() {
        activeTask?.cancel()
        activeTask = nil
        activeRequestID = nil
    }

    func finishRequest(_ requestID: TranslationRequestID) {
        guard isActive(requestID) else {
            return
        }

        activeTask = nil
        activeRequestID = nil
    }

    func isActive(_ requestID: TranslationRequestID) -> Bool {
        activeRequestID == requestID
    }
}
