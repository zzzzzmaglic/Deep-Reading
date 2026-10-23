import Foundation

enum ReadingReportResult: Sendable, Equatable {
    case generated(String)
    case unavailable(String)
}

protocol ReadingReportGenerating: Sendable {
    func generateReport(articleID: UUID) async throws -> ReadingReportResult
}

struct UnavailableReadingReportGenerator: ReadingReportGenerating {
    func generateReport(articleID: UUID) async throws -> ReadingReportResult {
        .unavailable("当前没有可用于生成阅读报告的笔记。")
    }
}
