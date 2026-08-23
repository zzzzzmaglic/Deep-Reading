import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class ArticleAssetSummaryCoordinatorTests: XCTestCase {
    func testLinkedNoteSummaryLayoutKeepsItsNoteInTheReservedThreeLineQuoteSlot() {
        let layout = ReadingAssetListRowLayout.linkedNoteContentLayout

        XCTAssertEqual(layout.quoteTopOffset, 34)
        XCTAssertEqual(layout.noteTopOffset, 94)
        XCTAssertEqual(layout.contentLeadingInset, 21)
        XCTAssertEqual(layout.accentTopOffset, 34)
    }

    func testStandaloneSummaryLayoutMovesOnlyItsContentSlotDownTwoPoints() {
        let layout = ReadingAssetListRowLayout.standaloneNoteContentLayout

        XCTAssertEqual(layout.contentTopOffset, 37)
        XCTAssertEqual(layout.accentTopOffset, 37)
        XCTAssertEqual(layout.contentLeadingInset, 21)
    }

    func testSummaryRowLayoutKeepsFixedCardsAndUsesTheApprovedContentLimits() {
        let linked = ReadingAssetListRowLayout.specification(for: .linkedNote)
        let standalone = ReadingAssetListRowLayout.specification(for: .standaloneNote)

        XCTAssertEqual(linked.cardHeight, 169)
        XCTAssertEqual(standalone.cardHeight, 169)
        XCTAssertEqual(linked.primaryTextLineLimit, 3)
        XCTAssertEqual(linked.noteTextLineLimit, 2)
        XCTAssertGreaterThanOrEqual(
            ReadingAssetListRowLayout.linkedNoteVisibleHeight,
            ReadingAssetListRowLayout.linkedNoteContentLayout.noteTopOffset + ReadingAssetListRowLayout.twoLineNoteHeight
        )
        XCTAssertEqual(standalone.primaryTextLineLimit, 6)
        XCTAssertNil(standalone.noteTextLineLimit)
        XCTAssertEqual(linked.primaryTextSize, 14)
        XCTAssertEqual(standalone.primaryTextSize, 14)
        XCTAssertEqual(linked.iconVerticalOffset, -2)
        XCTAssertEqual(standalone.iconVerticalOffset, -2)
    }

    func testShowInArticleReplacesSummaryWithAnchoredReaderRoute() {
        let articleID = UUID()
        let anchoredAsset = ReadingAsset(
            articleID: articleID,
            anchor: TextAnchor(
                id: UUID(), assetID: UUID(), articleID: articleID,
                startBlockID: UUID(), endBlockID: UUID(),
                startUTF16Offset: 3, endUTF16Offset: 8,
                selectedText: "划线内容", contentChecksum: "checksum"
            ),
            noteContent: nil
        )
        let coordinator = ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: .feed,
            articleRepository: SummaryTestArticleRepository(article: .summaryFixture(id: articleID)),
            readingAssetRepository: SummaryTestAssetRepository()
        )

        let route = coordinator.showInArticle(anchoredAsset)

        XCTAssertEqual(route.articleID, articleID)
        XCTAssertEqual(route.anchorID, anchoredAsset.anchor?.id)
        XCTAssertFalse(coordinator.navigationPath.contains(.summary(articleID)))
    }

    func testDeleteSelectedRefreshesOnlyAfterAllDeletesSucceed() async throws {
        let articleID = UUID()
        let first = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第一条",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let second = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第二条",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let repository = SummaryTestAssetRepository(assets: [first, second])
        let coordinator = ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: .feed,
            articleRepository: SummaryTestArticleRepository(article: .summaryFixture(id: articleID)),
            readingAssetRepository: repository
        )
        try await coordinator.load()

        try await coordinator.deleteSelectedAssets([first.id, second.id])

        let deletedAssetIDs = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDs, [first.id, second.id])
        XCTAssertEqual(coordinator.assets, [])
    }

    func testFailedBulkDeletionKeepsAssetsAndSelectionForRetry() async throws {
        let articleID = UUID()
        let first = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第一条",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let second = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第二条",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let repository = SummaryTestAssetRepository(assets: [first, second], failingAssetID: second.id)
        let coordinator = ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: .feed,
            articleRepository: SummaryTestArticleRepository(article: .summaryFixture(id: articleID)),
            readingAssetRepository: repository
        )
        try await coordinator.load()
        coordinator.toggleSelection(first.id)
        coordinator.toggleSelection(second.id)

        let deletionSucceeded = await coordinator.deleteSelection()
        XCTAssertFalse(deletionSucceeded)

        XCTAssertEqual(Set(coordinator.selectedAssetIDs), Set([first.id, second.id]))
        XCTAssertEqual(coordinator.assets.map(\.id), [first.id, second.id])
        XCTAssertNotNil(coordinator.deletionFailure)
    }

    func testRetrySkipsItemsWhoseDeleteRPCAlreadySucceeded() async throws {
        let articleID = UUID()
        let first = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第一条",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let second = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第二条",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let repository = SummaryTestAssetRepository(assets: [first, second], failingAssetID: second.id)
        let coordinator = ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: .feed,
            articleRepository: SummaryTestArticleRepository(article: .summaryFixture(id: articleID)),
            readingAssetRepository: repository
        )
        try await coordinator.load()
        coordinator.toggleSelection(first.id)
        coordinator.toggleSelection(second.id)

        let firstDeletionSucceeded = await coordinator.deleteSelection()
        XCTAssertFalse(firstDeletionSucceeded)
        await repository.clearDeleteFailure()
        let retrySucceeded = await coordinator.deleteSelection()
        XCTAssertTrue(retrySucceeded)

        let deletedAssetIDs = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDs, [first.id, second.id])
        XCTAssertEqual(coordinator.assets, [])
        XCTAssertTrue(coordinator.selectedAssetIDs.isEmpty)
        XCTAssertNil(coordinator.deletionFailure)
    }

    func testChangingSelectionAfterFailureResetsProgressForRemainingSelection() async throws {
        let articleID = UUID()
        let first = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第一条",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let second = ReadingAsset(
            articleID: articleID, anchor: nil, noteContent: "第二条",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let repository = SummaryTestAssetRepository(assets: [first, second], failingAssetID: second.id)
        let coordinator = ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: .feed,
            articleRepository: SummaryTestArticleRepository(article: .summaryFixture(id: articleID)),
            readingAssetRepository: repository
        )
        try await coordinator.load()
        coordinator.toggleSelection(first.id)
        coordinator.toggleSelection(second.id)

        let firstDeletionSucceeded = await coordinator.deleteSelection()
        XCTAssertFalse(firstDeletionSucceeded)
        coordinator.toggleSelection(first.id) // Remove the already-deleted ghost row.
        await repository.clearDeleteFailure()

        let retrySucceeded = await coordinator.deleteSelection()
        XCTAssertTrue(retrySucceeded)
        let deletedAssetIDs = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDs, [first.id, second.id])
        XCTAssertTrue(coordinator.selectedAssetIDs.isEmpty)
    }

    func testConcurrentDeletionRequestsAreSingleFlight() async throws {
        let articleID = UUID()
        let asset = ReadingAsset(articleID: articleID, anchor: nil, noteContent: "唯一条目")
        let repository = SummaryTestAssetRepository(assets: [asset], deleteDelay: .milliseconds(50))
        let coordinator = ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: .feed,
            articleRepository: SummaryTestArticleRepository(article: .summaryFixture(id: articleID)),
            readingAssetRepository: repository
        )
        try await coordinator.load()
        coordinator.toggleSelection(asset.id)

        let firstRequest = Task { @MainActor in await coordinator.deleteSelection() }
        while !coordinator.isDeleting { await Task.yield() }
        let concurrentRequestSucceeded = await coordinator.deleteSelection()
        XCTAssertFalse(concurrentRequestSucceeded)
        let firstRequestSucceeded = await firstRequest.value
        XCTAssertTrue(firstRequestSucceeded)

        let deletedAssetIDs = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDs, [asset.id])
        XCTAssertTrue(coordinator.selectedAssetIDs.isEmpty)
    }

    func testSortsAnchoredAssetsByBlockThenUTF16AndStandaloneNotesByNewestFirst() async throws {
        let articleID = UUID()
        let firstBlockID = UUID()
        let secondBlockID = UUID()
        let older = Date(timeIntervalSince1970: 10)
        let newer = Date(timeIntervalSince1970: 20)
        let laterInFirstBlock = ReadingAsset(articleID: articleID, anchor: .summaryAnchor(articleID: articleID, blockID: firstBlockID, offset: 9), noteContent: nil)
        let firstInSecondBlock = ReadingAsset(articleID: articleID, anchor: .summaryAnchor(articleID: articleID, blockID: secondBlockID, offset: 1), noteContent: nil)
        let firstInFirstBlock = ReadingAsset(articleID: articleID, anchor: .summaryAnchor(articleID: articleID, blockID: firstBlockID, offset: 2), noteContent: nil)
        let oldStandalone = ReadingAsset(articleID: articleID, anchor: nil, noteContent: "旧", createdAt: older)
        let newStandalone = ReadingAsset(articleID: articleID, anchor: nil, noteContent: "新", createdAt: newer)
        let article = Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [
                ArticleBlock(id: firstBlockID, articleID: articleID, position: 0, content: "甲"),
                ArticleBlock(id: secondBlockID, articleID: articleID, position: 1, content: "乙"),
            ]
        )
        let coordinator = ArticleAssetSummaryCoordinator(
            articleID: articleID,
            origin: .feed,
            articleRepository: SummaryTestArticleRepository(article: article),
            readingAssetRepository: SummaryTestAssetRepository(assets: [laterInFirstBlock, firstInSecondBlock, oldStandalone, firstInFirstBlock, newStandalone])
        )

        try await coordinator.load()

        XCTAssertEqual(coordinator.assets.map(\.id), [firstInFirstBlock.id, laterInFirstBlock.id, firstInSecondBlock.id, newStandalone.id, oldStandalone.id])
    }
}

private final class SummaryTestArticleRepository: ArticleRepository, @unchecked Sendable {
    let article: Article

    init(article: Article) { self.article = article }
    func readArticle(id: UUID) async throws -> Article { article }
    func readProgress(articleID: UUID) async throws -> ReaderPosition? { nil }
}

private actor SummaryTestAssetRepository: ReadingAssetRepository {
    private var assets: [ReadingAsset]
    private var failingAssetID: UUID?
    private let deleteDelay: Duration?
    private(set) var deletedAssetIDs: [UUID] = []

    init(
        assets: [ReadingAsset] = [],
        failingAssetID: UUID? = nil,
        deleteDelay: Duration? = nil
    ) {
        self.assets = assets
        self.failingAssetID = failingAssetID
        self.deleteDelay = deleteDelay
    }

    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] { assets }
    func deleteReadingAsset(id: UUID) async throws {
        if let deleteDelay { try await Task.sleep(for: deleteDelay) }
        if id == failingAssetID { throw SummaryTestError.deleteFailed }
        deletedAssetIDs.append(id)
        assets.removeAll { $0.id == id }
    }
    func clearDeleteFailure() { failingAssetID = nil }
    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset { fatalError("Not used") }
    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset { fatalError("Not used") }
    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {}
    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws {}
    func readTags() async throws -> [Tag] { [] }
    func createTag(name: String) async throws -> Tag { fatalError("Not used") }
    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
}

private enum SummaryTestError: Error { case deleteFailed }

private extension Article {
    static func summaryFixture(id: UUID) -> Article {
        Article(id: id, title: "标题", sourceName: "来源", contentChecksum: "checksum", blocks: [])
    }
}

private extension TextAnchor {
    static func summaryAnchor(articleID: UUID, blockID: UUID, offset: Int) -> TextAnchor {
        TextAnchor(
            id: UUID(), assetID: UUID(), articleID: articleID,
            startBlockID: blockID, endBlockID: blockID,
            startUTF16Offset: offset, endUTF16Offset: offset + 1,
            selectedText: "内容", contentChecksum: "checksum"
        )
    }
}
