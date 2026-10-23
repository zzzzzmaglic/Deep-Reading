import Foundation
import Supabase

enum AICompanionRepositoryError: Error, Equatable {
    case invalidEvent
}

final class SupabaseAICompanionRepository: AICompanionStreaming, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func stream(_ request: AICompanionRequest) -> AsyncThrowingStream<AICompanionStreamEvent, Error> {
        let upstream = client.functions._invokeWithStreamedResponse(
            "ai-companion",
            options: FunctionInvokeOptions(body: request, timeoutInterval: 180)
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = ""
                do {
                    for try await chunk in upstream {
                        try Task.checkCancellation()
                        buffer += String(decoding: chunk, as: UTF8.self)
                        while let boundary = buffer.range(of: "\n\n") {
                            let rawEvent = String(buffer[..<boundary.lowerBound])
                            buffer.removeSubrange(..<boundary.upperBound)
                            if let event = try Self.parse(rawEvent) {
                                continuation.yield(event)
                            }
                        }
                    }
                    if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let event = try Self.parse(buffer) {
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parse(_ rawEvent: String) throws -> AICompanionStreamEvent? {
        var name: String?
        var dataLines: [String] = []
        for line in rawEvent.components(separatedBy: .newlines) {
            if line.hasPrefix("event:") {
                name = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        guard let name else { return nil }
        let payloadData = Data(dataLines.joined(separator: "\n").utf8)
        let payload = (try? JSONSerialization.jsonObject(with: payloadData)) as? [String: Any]

        switch name {
        case "started": return .started
        case "delta":
            guard let content = payload?["content"] as? String else {
                throw AICompanionRepositoryError.invalidEvent
            }
            return .delta(content)
        case "completed": return .completed
        case "error": return .failed((payload?["code"] as? String) ?? "unknown_error")
        default: return nil
        }
    }
}
