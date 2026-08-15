import XCTest
@testable import DeepReadingVisualPrototype

final class SupabaseArticleRepositoryTests: XCTestCase {
    func testReadArticleReturnsTheRequestedArticleAndPositionOrderedBlocks() async throws {
        let articleID = UUID()
        let expected = Article(id: articleID, title: "Seed article", sourceName: "Test source", contentChecksum: "sha256:test", blocks: [
            ArticleBlock(id: UUID(), articleID: articleID, position: 1, content: "First"),
            ArticleBlock(id: UUID(), articleID: articleID, position: 2, content: "Second"),
        ])
        let remote = FakeSupabaseArticleRemote(article: expected)
        let article = try await SupabaseArticleRepository(remote: remote).readArticle(id: articleID)
        XCTAssertEqual(article, expected)
        XCTAssertEqual(remote.requestedArticleIDs, [articleID])
    }

    func testReadProgressReturnsNilWhenTheArticleHasNoPersistedPosition() async throws {
        let id = UUID()
        let remote = FakeSupabaseArticleRemote(article: Article(id: id, title: "Article", sourceName: "Source", contentChecksum: "checksum", blocks: []))
        let progress = try await SupabaseArticleRepository(remote: remote).readProgress(articleID: id)
        XCTAssertNil(progress)
    }
}

private final class FakeSupabaseArticleRemote: SupabaseArticleRemote, @unchecked Sendable {
    let article: Article
    var progress: ReaderPosition?
    private(set) var requestedArticleIDs: [UUID] = []
    init(article: Article, progress: ReaderPosition? = nil) { self.article = article; self.progress = progress }
    func readArticle(id: UUID) async throws -> Article { requestedArticleIDs.append(id); return article }
    func readProgress(articleID: UUID) async throws -> ReaderPosition? { progress }
}
