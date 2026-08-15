import XCTest
@testable import DeepReadingVisualPrototype

final class SupabaseReadingAssetRepositoryTests: XCTestCase {
    private let articleID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let anchoredAssetID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private let standaloneArticleAssetID = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!

    func testCreateHighlightUsesUTF16AnchorPayload() async throws {
        let remote = FakeSupabaseReadingAssetRemote()
        let repository = SupabaseReadingAssetRepository(remote: remote)
        let anchor = TextAnchor(
            id: UUID(),
            assetID: UUID(),
            articleID: articleID,
            startBlockID: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            endBlockID: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            startUTF16Offset: 6,
            endUTF16Offset: 14,
            selectedText: "UTF-16 摘录",
            contentChecksum: "old-checksum"
        )

        remote.rpcAssetID = anchoredAssetID
        remote.rowsByTable = assetRows(anchor: anchor)

        _ = try await repository.createHighlight(articleID: articleID, anchor: anchor, checksum: "sha256")

        XCTAssertEqual(remote.lastRPC?.name, "create_highlight_asset")
        XCTAssertEqual(remote.lastRPC?.parameters["p_article_id"] as? String, articleID.uuidString)
        XCTAssertEqual(remote.lastRPC?.parameters["p_start_utf16_offset"] as? Int, 6)
        XCTAssertEqual(remote.lastRPC?.parameters["p_end_utf16_offset"] as? Int, 14)
        XCTAssertEqual(remote.lastRPC?.parameters["p_content_checksum"] as? String, "sha256")
    }

    func testAssetsJoinAnchorAndTagsBeforeFilteringCurrentArticle() async throws {
        let remote = FakeSupabaseReadingAssetRemote()
        let repository = SupabaseReadingAssetRepository(remote: remote)
        let anchor = TextAnchor(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            assetID: anchoredAssetID,
            articleID: articleID,
            startBlockID: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            endBlockID: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            startUTF16Offset: 6,
            endUTF16Offset: 14,
            selectedText: "UTF-16 摘录",
            contentChecksum: "sha256"
        )
        remote.rowsByTable = assetRows(anchor: anchor)

        let assets = try await repository.readAssets(articleID: articleID)

        XCTAssertEqual(assets.map(\.id), [anchoredAssetID, standaloneArticleAssetID])
        XCTAssertEqual(assets.first?.tags.map(\.name), ["摘录与思考", "商业化"])
    }

    func testStandaloneNoteMutationSendsNullableArticleAndRefreshesReturnedAsset() async throws {
        let remote = FakeSupabaseReadingAssetRemote()
        let repository = SupabaseReadingAssetRepository(remote: remote)
        let globalAssetID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
        remote.rpcAssetID = globalAssetID
        remote.rowsByTable = [
            "reading_assets": [[
                "id": globalAssetID.uuidString,
                "owner_id": UUID().uuidString,
                "article_id": NSNull(),
                "note_content": "全局笔记",
            ]],
            "asset_anchors": [],
            "tags": [],
            "asset_tags": [],
        ]

        let asset = try await repository.createStandaloneNote(articleID: nil, noteContent: "全局笔记")

        XCTAssertEqual(remote.lastRPC?.name, "create_standalone_note")
        XCTAssertTrue(remote.lastRPC?.parameters["p_article_id"] is NSNull)
        XCTAssertEqual(remote.lastRPC?.parameters["p_note_content"] as? String, "全局笔记")
        XCTAssertEqual(asset.id, globalAssetID)
    }

    func testTagAndProgressMutationsUseDeclaredRPCPayloads() async throws {
        let remote = FakeSupabaseReadingAssetRemote()
        let repository = SupabaseReadingAssetRepository(remote: remote)
        let assetID = UUID()
        let tagIDs = [UUID(), UUID()]
        let blockID = UUID()

        try await repository.setAssetTags(assetID: assetID, tagIDs: tagIDs)
        XCTAssertEqual(remote.lastRPC?.name, "set_asset_tags")
        XCTAssertEqual(remote.lastRPC?.parameters["p_asset_id"] as? String, assetID.uuidString)
        XCTAssertEqual(remote.lastRPC?.parameters["p_tag_ids"] as? [String], tagIDs.map(\.uuidString))

        try await repository.upsertReadingProgress(
            articleID: articleID,
            position: ReaderPosition(blockID: blockID, utf16Offset: 9)
        )
        XCTAssertEqual(remote.lastRPC?.name, "upsert_reading_progress")
        XCTAssertEqual(remote.lastRPC?.parameters["p_block_id"] as? String, blockID.uuidString)
        XCTAssertEqual(remote.lastRPC?.parameters["p_utf16_offset"] as? Int, 9)
    }

    private func assetRows(anchor: TextAnchor) -> [String: [[String: Any]]] {
        let ownerID = UUID().uuidString
        let otherArticleID = UUID().uuidString
        let systemTagID = UUID().uuidString
        let commercialTagID = UUID().uuidString

        return [
            "reading_assets": [
                ["id": anchoredAssetID.uuidString, "owner_id": ownerID, "article_id": NSNull(), "note_content": NSNull()],
                ["id": standaloneArticleAssetID.uuidString, "owner_id": ownerID, "article_id": articleID.uuidString, "note_content": "文章笔记"],
                ["id": UUID().uuidString, "owner_id": ownerID, "article_id": otherArticleID, "note_content": "其他文章笔记"],
            ],
            "asset_anchors": [[
                "id": anchor.id.uuidString,
                "asset_id": anchor.assetID.uuidString,
                "article_id": anchor.articleID.uuidString,
                "start_block_id": anchor.startBlockID.uuidString,
                "end_block_id": anchor.endBlockID.uuidString,
                "start_utf16_offset": anchor.startUTF16Offset,
                "end_utf16_offset": anchor.endUTF16Offset,
                "selected_text": anchor.selectedText,
                "content_checksum": anchor.contentChecksum,
            ]],
            "tags": [
                ["id": systemTagID, "owner_id": ownerID, "name": "摘录与思考", "is_system": true],
                ["id": commercialTagID, "owner_id": ownerID, "name": "商业化", "is_system": false],
            ],
            "asset_tags": [
                ["asset_id": anchoredAssetID.uuidString, "tag_id": systemTagID],
                ["asset_id": anchoredAssetID.uuidString, "tag_id": commercialTagID],
            ],
        ]
    }
}
