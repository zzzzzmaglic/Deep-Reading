import Foundation
import Supabase

protocol SupabaseReadingReportRemote: Sendable {
    func generate(articleID: UUID) async throws -> SupabaseReadingReportResponse
}

struct SupabaseReadingReportResponse: Decodable, Sendable, Equatable {
    let status: String
    let body: String?
    let message: String?
}

enum SupabaseReadingReportError: Error, Equatable {
    case invalidResponse
}

final class SupabaseReadingReportGenerator: ReadingReportGenerating, @unchecked Sendable {
    private let remote: any SupabaseReadingReportRemote

    init(client: SupabaseClient) {
        remote = LiveSupabaseReadingReportRemote(client: client)
    }

    init(remote: any SupabaseReadingReportRemote) {
        self.remote = remote
    }

    func generateReport(articleID: UUID) async throws -> ReadingReportResult {
        let response = try await remote.generate(articleID: articleID)
        switch response.status {
        case "generated":
            guard let body = response.body?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !body.isEmpty else {
                throw SupabaseReadingReportError.invalidResponse
            }
            return .generated(body)
        case "unavailable":
            let message = response.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .unavailable(message?.isEmpty == false
                ? message!
                : "当前没有可用于生成阅读报告的笔记。")
        default:
            throw SupabaseReadingReportError.invalidResponse
        }
    }
}

private struct ReadingReportRequest: Encodable {
    let articleId: UUID
}

private final class LiveSupabaseReadingReportRemote: SupabaseReadingReportRemote, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func generate(articleID: UUID) async throws -> SupabaseReadingReportResponse {
        try await client.functions.invoke(
            "reading-report",
            options: FunctionInvokeOptions(
                body: ReadingReportRequest(articleId: articleID),
                // The handoff contract allows up to 120 seconds for each of
                // the two sequential model calls, plus gateway overhead.
                timeoutInterval: 260
            )
        )
    }
}
