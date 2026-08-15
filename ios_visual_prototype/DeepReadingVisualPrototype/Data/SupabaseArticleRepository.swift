import Foundation
import Supabase

final class SupabaseArticleRepository: ArticleRepository, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func readArticle(id: UUID) async throws -> Article {
        let articleResponse: PostgrestResponse<ArticleRecord> = try await client
            .from("articles")
            .select("id,title,source_name,content_checksum")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
        let blockResponse: PostgrestResponse<[ArticleBlock]> = try await client
            .from("article_blocks")
            .select("id,article_id,position,content")
            .eq("article_id", value: id.uuidString)
            .order("position", ascending: true)
            .execute()

        return Article(
            id: articleResponse.value.id,
            title: articleResponse.value.title,
            sourceName: articleResponse.value.sourceName,
            contentChecksum: articleResponse.value.contentChecksum,
            blocks: blockResponse.value
        )
    }

    func readProgress(articleID: UUID) async throws -> ReaderPosition? {
        let response: PostgrestResponse<ReaderPosition?> = try await client
            .from("reading_progress")
            .select("block_id,utf16_offset")
            .eq("article_id", value: articleID.uuidString)
            .maybeSingle()
            .execute()
        return response.value
    }
}

private struct ArticleRecord: Decodable {
    let id: UUID
    let title: String
    let sourceName: String
    let contentChecksum: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sourceName = "source_name"
        case contentChecksum = "content_checksum"
    }
}
