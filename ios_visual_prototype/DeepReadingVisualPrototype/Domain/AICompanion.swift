import Foundation

enum AICompanionRequestType: String, Codable, Sendable {
    case question
    case selectionExplain = "selection_explain"
    case highlightExplain = "highlight_explain"
}

struct AICompanionAnchor: Codable, Sendable, Equatable {
    let startBlockId: UUID
    let endBlockId: UUID
}

struct AICompanionHistoryMessage: Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable { case user, assistant }

    let role: Role
    let content: String
}

struct AICompanionRequest: Codable, Sendable, Equatable {
    let articleId: UUID
    let requestType: AICompanionRequestType
    let question: String
    let anchor: AICompanionAnchor?
    let quotedText: String?
    let history: [AICompanionHistoryMessage]
}

enum AICompanionStreamEvent: Sendable, Equatable {
    case started
    case delta(String)
    case completed
    case failed(String)
}

protocol AICompanionStreaming: Sendable {
    func stream(_ request: AICompanionRequest) -> AsyncThrowingStream<AICompanionStreamEvent, Error>
}

struct UnavailableAICompanionRepository: AICompanionStreaming {
    func stream(_ request: AICompanionRequest) -> AsyncThrowingStream<AICompanionStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.failed("AI 伴读暂时不可用"))
            continuation.finish()
        }
    }
}

struct AICompanionReference: Sendable, Equatable {
    let text: String
    let anchor: AICompanionAnchor
    let requestType: AICompanionRequestType
}

struct AICompanionMessage: Identifiable, Sendable, Equatable {
    enum Role: Sendable { case user, assistant }
    enum State: Sendable { case complete, generating, stopped, failed }

    let id: UUID
    let role: Role
    var text: String
    let referenceText: String?
    var state: State

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        referenceText: String? = nil,
        state: State = .complete
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.referenceText = referenceText
        self.state = state
    }

    var historyContent: String {
        guard let referenceText else { return text }
        guard !text.isEmpty else { return "引用：\(referenceText)" }
        return "引用：\(referenceText)\n\(text)"
    }
}
