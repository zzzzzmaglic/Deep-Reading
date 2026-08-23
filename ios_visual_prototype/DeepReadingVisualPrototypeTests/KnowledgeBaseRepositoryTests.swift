import XCTest
@testable import DeepReadingVisualPrototype

final class KnowledgeBaseRepositoryTests: XCTestCase {
    private let collectionID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let visibleArticleID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let hiddenArticleID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    private let articleID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    private let firstID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    private let secondID = UUID(uuidString: "50000000-0000-0000-0000-000000000002")!

    func testReadCollectionArticlesExcludesOnlyCurrentOwnersHiddenRows() async throws {
        let remote = FakeSupabaseKnowledgeBaseRemote()
        remote.rowsByTable = collectionArticleRows()
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        let articles = try await repository.readCollectionArticles(collectionID: collectionID)

        XCTAssertEqual(articles.map(\.id), [visibleArticleID])
    }

    func testRemoveArticlesUsesTheAtomicCollectionRPC() async throws {
        let remote = FakeSupabaseKnowledgeBaseRemote()
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        try await repository.removeArticlesFromCollection(collectionID: collectionID, articleIDs: [articleID])

        XCTAssertEqual(remote.lastRPC?.name, "remove_articles_from_collection")
        XCTAssertEqual(remote.lastRPC?.parameters["p_collection_id"] as? String, collectionID.uuidString)
        XCTAssertEqual(remote.lastRPC?.parameters["p_article_ids"] as? [String], [articleID.uuidString])
    }

    func testSystemTagBatchDeleteUsesOneRPCInsteadOfLoopingPerAsset() async throws {
        let remote = FakeSupabaseReadingAssetRemote()
        let assetRepository = SupabaseReadingAssetRepository(remote: remote)

        try await assetRepository.deleteReadingAssets(ids: [firstID, secondID])

        XCTAssertEqual(remote.rpcCalls.map(\.name), ["delete_reading_assets"])
        XCTAssertEqual(remote.rpcCalls.first?.parameters["p_asset_ids"] as? [String], [firstID.uuidString, secondID.uuidString])
    }

    private func collectionArticleRows() -> [String: [[String: Any]]] {
        [
            "article_collections": [
                ["article_id": visibleArticleID.uuidString, "collection_id": collectionID.uuidString, "position": 1],
                ["article_id": hiddenArticleID.uuidString, "collection_id": collectionID.uuidString, "position": 2],
            ],
            "collection_article_exclusions": [
                ["owner_id": UUID().uuidString, "collection_id": collectionID.uuidString, "article_id": hiddenArticleID.uuidString],
            ],
            "articles": [
                articleRow(id: visibleArticleID, title: "Visible"),
                articleRow(id: hiddenArticleID, title: "Hidden"),
            ],
            "reading_assets": [["id": UUID().uuidString, "article_id": visibleArticleID.uuidString]],
        ]
    }

    private func articleRow(id: UUID, title: String) -> [String: Any] {
        [
            "id": id.uuidString,
            "title": title,
            "source_name": "Test source",
            "cover_asset_name": "KnowledgeCoverPlaceholder",
            "cognitive_dimension": "方法论",
            "published_at": "2026-08-23T00:00:00Z",
        ]
    }
}
