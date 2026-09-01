import XCTest
@testable import DeepReadingVisualPrototype

final class KnowledgeBaseRepositoryTests: XCTestCase {
    private let collectionID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let currentOwnerID = UUID(uuidString: "90000000-0000-0000-0000-000000000001")!
    private let foreignOwnerID = UUID(uuidString: "90000000-0000-0000-0000-000000000002")!
    private let visibleArticleID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let hiddenArticleID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    private let articleID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    private let firstID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    private let secondID = UUID(uuidString: "50000000-0000-0000-0000-000000000002")!

    func testReadCollectionArticlesExcludesOnlyCurrentOwnersHiddenRows() async throws {
        let remote = FakeSupabaseKnowledgeBaseRemote()
        remote.currentOwnerID = currentOwnerID
        remote.rowsByTable = collectionArticleRows()
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        let articles = try await repository.readCollectionArticles(collectionID: collectionID)

        XCTAssertEqual(articles.map(\.id), [visibleArticleID])
    }

    func testHomeAndCollectionCountsExcludeOnlyCurrentOwnersRows() async throws {
        let remote = FakeSupabaseKnowledgeBaseRemote()
        remote.currentOwnerID = currentOwnerID
        remote.rowsByTable = collectionCountRows()
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        let home = try await repository.readHome()
        let collection = try await repository.readCollection(id: collectionID)

        XCTAssertEqual(home.collections.first?.visibleArticleCount, 1)
        XCTAssertEqual(collection.visibleArticleCount, 1)
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

    func testCollectionPreviewRetainsExportedKnowledgeCoverAssetName() async throws {
        let remote = FakeSupabaseKnowledgeBaseRemote()
        remote.currentOwnerID = currentOwnerID
        remote.rowsByTable = collectionArticleRows()
        remote.rowsByTable["articles"] = [articleRow(id: visibleArticleID, title: "Visible", coverAssetName: "KnowledgeCover1")]
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        let previews = try await repository.readCollectionArticles(collectionID: collectionID)

        XCTAssertEqual(previews.single?.coverAssetName, "KnowledgeCover1")
    }

    func testCollectionPreviewAcceptsFractionalSecondPublicationTimes() async throws {
        let remote = FakeSupabaseKnowledgeBaseRemote()
        remote.currentOwnerID = currentOwnerID
        var rows = collectionArticleRows()
        rows["articles"] = [
            articleRow(
                id: visibleArticleID,
                title: "Visible",
                publishedAt: "2026-08-25T08:36:45.37148+00:00"
            )
        ]
        remote.rowsByTable = rows
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        let previews = try await repository.readCollectionArticles(collectionID: collectionID)

        XCTAssertEqual(previews.single?.id, visibleArticleID)
    }

    func testCollectionPreviewCountsUniqueCurrentOwnerAssetsFromAnchorsAndStandaloneNotes() async throws {
        let anchoredAssetID = UUID(uuidString: "50000000-0000-0000-0000-000000000010")!
        let standaloneAssetID = UUID(uuidString: "50000000-0000-0000-0000-000000000011")!
        let foreignAssetID = UUID(uuidString: "50000000-0000-0000-0000-000000000012")!
        let remote = FakeSupabaseKnowledgeBaseRemote()
        remote.currentOwnerID = currentOwnerID
        var rows = collectionArticleRows()
        rows["reading_assets"] = [
            ["id": anchoredAssetID.uuidString, "owner_id": currentOwnerID.uuidString],
            ["id": standaloneAssetID.uuidString, "owner_id": currentOwnerID.uuidString, "article_id": visibleArticleID.uuidString],
            ["id": foreignAssetID.uuidString, "owner_id": foreignOwnerID.uuidString, "article_id": hiddenArticleID.uuidString],
        ]
        rows["asset_anchors"] = [
            ["asset_id": anchoredAssetID.uuidString, "owner_id": currentOwnerID.uuidString, "article_id": visibleArticleID.uuidString],
            ["asset_id": foreignAssetID.uuidString, "owner_id": foreignOwnerID.uuidString, "article_id": hiddenArticleID.uuidString],
        ]
        remote.rowsByTable = rows
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        let previews = try await repository.readCollectionArticles(collectionID: collectionID)

        XCTAssertEqual(previews.single?.readingAssetCount, 2)
    }

    func testCollectionPreviewCapsReadingAssetCountAtNinetyNine() async throws {
        let remote = FakeSupabaseKnowledgeBaseRemote()
        remote.currentOwnerID = currentOwnerID
        var rows = collectionArticleRows()
        rows["reading_assets"] = (0 ..< 100).map { offset in
            [
                "id": UUID(uuidString: String(format: "50000000-0000-0000-0000-%012d", offset))!.uuidString,
                "owner_id": currentOwnerID.uuidString,
                "article_id": visibleArticleID.uuidString,
            ]
        }
        remote.rowsByTable = rows
        let repository = SupabaseKnowledgeBaseRepository(remote: remote)

        let previews = try await repository.readCollectionArticles(collectionID: collectionID)

        XCTAssertEqual(previews.single?.readingAssetCount, 99)
    }

    private func collectionArticleRows() -> [String: [[String: Any]]] {
        [
            "article_collections": [
                ["article_id": visibleArticleID.uuidString, "collection_id": collectionID.uuidString, "position": 1],
                ["article_id": hiddenArticleID.uuidString, "collection_id": collectionID.uuidString, "position": 2],
            ],
            "collection_article_exclusions": [
                ["owner_id": currentOwnerID.uuidString, "collection_id": collectionID.uuidString, "article_id": hiddenArticleID.uuidString],
                ["owner_id": foreignOwnerID.uuidString, "collection_id": collectionID.uuidString, "article_id": visibleArticleID.uuidString],
            ],
            "articles": [
                articleRow(id: visibleArticleID, title: "Visible"),
                articleRow(id: hiddenArticleID, title: "Hidden"),
            ],
            "reading_assets": [["id": UUID().uuidString, "owner_id": currentOwnerID.uuidString, "article_id": visibleArticleID.uuidString]],
        ]
    }

    private func collectionCountRows() -> [String: [[String: Any]]] {
        var rows = collectionArticleRows()
        rows["collections"] = [[
            "id": collectionID.uuidString,
            "name": "Test collection",
            "description": "Owner-scoped exclusions",
            "is_system": false,
        ]]
        rows["tags"] = []
        return rows
    }

    private func articleRow(
        id: UUID,
        title: String,
        coverAssetName: String = "KnowledgeCoverPlaceholder",
        publishedAt: String = "2026-08-23T00:00:00Z"
    ) -> [String: Any] {
        [
            "id": id.uuidString,
            "title": title,
            "source_name": "Test source",
            "cover_asset_name": coverAssetName,
            "cognitive_dimension": "方法论",
            "published_at": publishedAt,
        ]
    }
}

private extension Collection where Element == KnowledgeArticlePreview {
    var single: Element? { count == 1 ? first : nil }
}
