import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class ReaderCoordinatorTests: XCTestCase {
    func testShowcaseNormalRouteStartsAtFirstBlockInsteadOfPersistedProgress() async throws {
        let articleID = UUID()
        let firstBlockID = UUID()
        let secondBlockID = UUID()
        let article = Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [
                ArticleBlock(id: firstBlockID, articleID: articleID, position: 0, content: "第一段", kind: .paragraph),
                ArticleBlock(id: secondBlockID, articleID: articleID, position: 1, content: "第二段", kind: .paragraph),
            ]
        )
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(
            articleRepository: ReaderTestArticleRepository(
                article: article,
                progress: ReaderPosition(blockID: secondBlockID, utf16Offset: 3)
            ),
            readingAssetRepository: ReaderTestAssetRepository(),
            startsNormalRoutesAtBeginning: true
        ))

        try await coordinator.load(route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed))

        XCTAssertEqual(coordinator.initialPosition, ReaderPosition(blockID: firstBlockID, utf16Offset: 0))
    }

    func testProgressWritesOnceAfter350Milliseconds() async throws {
        let articleID = UUID()
        let firstBlockID = UUID()
        let secondBlockID = UUID()
        let article = Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [
                ArticleBlock(id: firstBlockID, articleID: articleID, position: 0, content: "第一段文字", kind: .paragraph),
                ArticleBlock(id: secondBlockID, articleID: articleID, position: 1, content: "第二段内容", kind: .paragraph),
            ]
        )
        let articles = ReaderTestArticleRepository(article: article)
        let assets = ReaderTestAssetRepository()
        let coordinator = ReaderCoordinator(
            dependencies: ReaderDependencies(articleRepository: articles, readingAssetRepository: assets),
            progressDebounce: .milliseconds(350)
        )
        try await coordinator.load(route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed))
        let layout = ReaderTextLayout(article: article, image: nil)
        let firstBlockRange = try XCTUnwrap(layout.range(forBlockID: firstBlockID))
        let secondBlockRange = try XCTUnwrap(layout.range(forBlockID: secondBlockID))

        coordinator.queueProgress(visibleUTF16Location: firstBlockRange.location + 2)
        coordinator.queueProgress(visibleUTF16Location: secondBlockRange.location + 4)
        try await Task.sleep(for: .milliseconds(340))
        let earlyProgressWrites = await assets.progressWritesSnapshot()
        XCTAssertTrue(earlyProgressWrites.isEmpty)
        for _ in 0 ..< 50 {
            if !(await assets.progressWritesSnapshot()).isEmpty { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        let progressWrites = await assets.progressWrites
        XCTAssertEqual(progressWrites, [ReaderPosition(blockID: secondBlockID, utf16Offset: 4)])
    }

    func testRouteAnchorIsPreferredOverPersistedProgress() async throws {
        let articleID = UUID()
        let firstBlockID = UUID()
        let secondBlockID = UUID()
        let anchorID = UUID()
        let article = Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [
                ArticleBlock(id: firstBlockID, articleID: articleID, position: 0, content: "第一段", kind: .paragraph),
                ArticleBlock(id: secondBlockID, articleID: articleID, position: 1, content: "第二段", kind: .paragraph),
            ]
        )
        let anchor = TextAnchor(id: anchorID, assetID: UUID(), articleID: articleID, startBlockID: secondBlockID, endBlockID: secondBlockID, startUTF16Offset: 1, endUTF16Offset: 2, selectedText: "二", contentChecksum: "checksum")
        let articles = ReaderTestArticleRepository(article: article, progress: ReaderPosition(blockID: firstBlockID, utf16Offset: 0))
        let assets = ReaderTestAssetRepository(assets: [ReadingAsset(anchor: anchor, noteContent: nil)])
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(articleRepository: articles, readingAssetRepository: assets))

        try await coordinator.load(route: ReaderRoute(articleID: articleID, anchorID: anchorID, origin: .knowledge))

        XCTAssertEqual(coordinator.initialPosition, ReaderPosition(blockID: secondBlockID, utf16Offset: 1))
        XCTAssertEqual(coordinator.scrollRequestRevision, 1)

        coordinator.consumeInitialPosition()
        XCTAssertEqual(
            coordinator.scrollRequestRevision,
            1,
            "Consuming a one-shot position must not erase the viewport identity that applies the route anchor."
        )
    }

    func testInitialPositionIsConsumedAfterTextKitAppliesIt() async throws {
        let articleID = UUID()
        let blockID = UUID()
        let article = Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [ArticleBlock(id: blockID, articleID: articleID, position: 0, content: "正文", kind: .paragraph)]
        )
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(
            articleRepository: ReaderTestArticleRepository(
                article: article,
                progress: ReaderPosition(blockID: blockID, utf16Offset: 1)
            ),
            readingAssetRepository: ReaderTestAssetRepository()
        ))

        try await coordinator.load(route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed))
        XCTAssertNotNil(coordinator.initialPosition)

        coordinator.consumeInitialPosition()

        XCTAssertNil(coordinator.initialPosition)
    }

    func testScrollAndTapToggleChromeImmediately() async throws {
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(articleRepository: ReaderTestArticleRepository(article: .empty), readingAssetRepository: ReaderTestAssetRepository()))
        coordinator.handleScroll(direction: .down)
        XCTAssertFalse(coordinator.chromeIsVisible)

        coordinator.handleBodyTap()
        XCTAssertTrue(coordinator.chromeIsVisible)

        coordinator.handleBodyTap()
        XCTAssertFalse(coordinator.chromeIsVisible)

        coordinator.handleScroll(direction: .up)
        XCTAssertTrue(coordinator.chromeIsVisible)
    }

    func testAssetLoadFailureDoesNotBlockTheArticleOrProgressRestore() async throws {
        let articleID = UUID()
        let blockID = UUID()
        let article = Article(
            id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum",
            blocks: [ArticleBlock(id: blockID, articleID: articleID, position: 0, content: "正文", kind: .paragraph)]
        )
        let coordinator = ReaderCoordinator(
            dependencies: ReaderDependencies(
                articleRepository: ReaderTestArticleRepository(
                    article: article,
                    progress: ReaderPosition(blockID: blockID, utf16Offset: 1)
                ),
                readingAssetRepository: ReaderTestAssetRepository(readError: true)
            )
        )

        try await coordinator.load(route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed))

        XCTAssertEqual(coordinator.article?.id, articleID)
        XCTAssertEqual(coordinator.initialPosition, ReaderPosition(blockID: blockID, utf16Offset: 1))
        for _ in 0 ..< 20 where coordinator.assetFailure == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(coordinator.assetFailure, .assetsFailed)
    }

    func testProgrammaticRestoreDoesNotProduceChromeScrollDirection() {
        var classifier = ReaderScrollEventClassifier()

        XCTAssertNil(classifier.direction(for: 120, isUserDriven: false))
        XCTAssertEqual(classifier.direction(for: 140, isUserDriven: true), .down)
        XCTAssertEqual(classifier.direction(for: 120, isUserDriven: true), .up)
    }

    func testOnlyUserDrivenScrollsCanPublishReaderProgress() {
        XCTAssertFalse(ReaderScrollEventClassifier.isUserDriven(
            isTracking: false,
            isDragging: false,
            isDecelerating: false,
            isRestoringRange: false
        ))
        XCTAssertFalse(ReaderScrollEventClassifier.isUserDriven(
            isTracking: true,
            isDragging: false,
            isDecelerating: false,
            isRestoringRange: true
        ))
        XCTAssertTrue(ReaderScrollEventClassifier.isUserDriven(
            isTracking: false,
            isDragging: true,
            isDecelerating: false,
            isRestoringRange: false
        ))
    }

    func testTextDocumentUpdateGateSkipsEquivalentSwiftUIRefreshes() {
        let articleID = UUID()
        let revision = ReaderTextDocumentRevision(
            articleID: articleID,
            contentChecksum: "checksum",
            highlights: []
        )
        let changedRevision = ReaderTextDocumentRevision(
            articleID: articleID,
            contentChecksum: "checksum",
            highlights: [TextAnchor(
                id: UUID(),
                assetID: UUID(),
                articleID: articleID,
                startBlockID: UUID(),
                endBlockID: UUID(),
                startUTF16Offset: 0,
                endUTF16Offset: 1,
                selectedText: "正文",
                contentChecksum: "checksum"
            )]
        )
        var gate = ReaderTextDocumentUpdateGate()

        XCTAssertTrue(gate.shouldApply(revision))
        XCTAssertFalse(gate.shouldApply(revision))
        XCTAssertTrue(gate.shouldApply(changedRevision))
    }

    func testNormalRoutePublishesProgressBeforeDelayedAssetsArrive() async throws {
        let articleID = UUID()
        let blockID = UUID()
        let article = Article(id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum", blocks: [ArticleBlock(id: blockID, articleID: articleID, position: 0, content: "正文", kind: .paragraph)])
        let assets = ReaderTestAssetRepository(
            assets: [ReadingAsset(anchor: nil, noteContent: "asset")],
            readDelay: .milliseconds(180)
        )
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(
            articleRepository: ReaderTestArticleRepository(article: article, progress: ReaderPosition(blockID: blockID, utf16Offset: 1)),
            readingAssetRepository: assets
        ))

        try await coordinator.load(route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed))

        XCTAssertEqual(coordinator.initialPosition, ReaderPosition(blockID: blockID, utf16Offset: 1))
        XCTAssertTrue(coordinator.assets.isEmpty)
        try await Task.sleep(for: .milliseconds(240))
        XCTAssertEqual(coordinator.assets.count, 1)
    }

    func testSupersededRouteCannotReplaceNewerArticleOrProgress() async throws {
        let oldID = UUID()
        let newID = UUID()
        let oldBlock = UUID()
        let newBlock = UUID()
        let oldArticle = Article(id: oldID, title: "旧", sourceName: "来源", contentChecksum: "old", blocks: [ArticleBlock(id: oldBlock, articleID: oldID, position: 0, content: "旧正文", kind: .paragraph)])
        let newArticle = Article(id: newID, title: "新", sourceName: "来源", contentChecksum: "new", blocks: [ArticleBlock(id: newBlock, articleID: newID, position: 0, content: "新正文", kind: .paragraph)])
        let repository = ReaderRoutingArticleRepository(
            articles: [oldID: oldArticle, newID: newArticle],
            progress: [oldID: ReaderPosition(blockID: oldBlock, utf16Offset: 1), newID: ReaderPosition(blockID: newBlock, utf16Offset: 2)],
            delayedID: oldID
        )
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(articleRepository: repository, readingAssetRepository: ReaderTestAssetRepository()))

        Task { try? await coordinator.load(route: ReaderRoute(articleID: oldID, anchorID: nil, origin: .feed)) }
        try await Task.sleep(for: .milliseconds(25))
        try await coordinator.load(route: ReaderRoute(articleID: newID, anchorID: nil, origin: .feed))
        try await Task.sleep(for: .milliseconds(180))

        XCTAssertEqual(coordinator.article?.id, newID)
        XCTAssertEqual(coordinator.initialPosition, ReaderPosition(blockID: newBlock, utf16Offset: 2))
    }

    func testSupersededProgressWriteCannotSetFailureAfterNewerWrite() async throws {
        let articleID = UUID()
        let blockID = UUID()
        let article = Article(id: articleID, title: "标题", sourceName: "来源", contentChecksum: "checksum", blocks: [ArticleBlock(id: blockID, articleID: articleID, position: 0, content: "甲乙丙丁", kind: .paragraph)])
        let assets = ReaderTestAssetRepository(firstProgressWriteFailsAfter: .milliseconds(220))
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(articleRepository: ReaderTestArticleRepository(article: article), readingAssetRepository: assets))
        try await coordinator.load(route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed))
        let layout = ReaderTextLayout(article: article, image: nil)
        let blockRange = try XCTUnwrap(layout.range(forBlockID: blockID))

        coordinator.queueProgress(visibleUTF16Location: blockRange.location + 1)
        await assets.waitForFirstProgressWrite()
        coordinator.queueProgress(visibleUTF16Location: blockRange.location + 2)
        try await Task.sleep(for: .milliseconds(620))

        XCTAssertNil(coordinator.progressFailure)
        let progressWrites = await assets.progressWrites
        XCTAssertEqual(progressWrites, [ReaderPosition(blockID: blockID, utf16Offset: 2)])
    }

    func testOldAssetCardSuccessCannotCloseNewerCardAfterRouteChange() async throws {
        let oldArticleID = UUID()
        let newArticleID = UUID()
        let oldBlockID = UUID()
        let newBlockID = UUID()
        let oldArticle = Article(
            id: oldArticleID,
            title: "标题",
            sourceName: "来源",
            contentChecksum: "checksum",
            blocks: [ArticleBlock(id: oldBlockID, articleID: oldArticleID, position: 0, content: "旧正文", kind: .paragraph)]
        )
        let newArticle = Article(
            id: newArticleID,
            title: "新标题",
            sourceName: "来源",
            contentChecksum: "new-checksum",
            blocks: [ArticleBlock(id: newBlockID, articleID: newArticleID, position: 0, content: "新正文", kind: .paragraph)]
        )
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(
            articleRepository: ReaderRoutingArticleRepository(
                articles: [oldArticleID: oldArticle, newArticleID: newArticle],
                progress: [:],
                delayedID: UUID()
            ),
            readingAssetRepository: ReaderTestAssetRepository()
        ))
        try await coordinator.load(route: ReaderRoute(articleID: oldArticleID, anchorID: nil, origin: .feed))

        XCTAssertNotNil(coordinator.beginStandaloneNote())
        let oldToken = try XCTUnwrap(coordinator.assetCardToken)
        try await coordinator.load(route: ReaderRoute(articleID: newArticleID, anchorID: nil, origin: .feed))
        XCTAssertNotNil(coordinator.beginStandaloneNote())
        let newToken = try XCTUnwrap(coordinator.assetCardToken)
        XCTAssertNotEqual(oldToken, newToken)

        coordinator.completeAssetCardSave(token: oldToken, restoring: ReaderChromeState(isVisible: true))

        XCTAssertEqual(coordinator.assetCardToken, newToken)
        XCTAssertNotNil(coordinator.presentedAssetDraft)
    }
}

private final class ReaderTestArticleRepository: ArticleRepository, @unchecked Sendable {
    let article: Article
    let progress: ReaderPosition?

    init(article: Article, progress: ReaderPosition? = nil) { self.article = article; self.progress = progress }
    func readArticle(id: UUID) async throws -> Article { article }
    func readProgress(articleID: UUID) async throws -> ReaderPosition? { progress }
}

private actor ReaderTestAssetRepository: ReadingAssetRepository {
    let assets: [ReadingAsset]
    let readError: Bool
    let readDelay: Duration?
    let firstProgressWriteFailsAfter: Duration?
    private(set) var progressWrites: [ReaderPosition] = []
    private var progressAttempts = 0
    private var firstProgressWriteWaiters: [CheckedContinuation<Void, Never>] = []

    init(assets: [ReadingAsset] = [], readError: Bool = false, readDelay: Duration? = nil, firstProgressWriteFailsAfter: Duration? = nil) {
        self.assets = assets
        self.readError = readError
        self.readDelay = readDelay
        self.firstProgressWriteFailsAfter = firstProgressWriteFailsAfter
    }
    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] {
        if let readDelay { try? await Task.sleep(for: readDelay) }
        if readError { throw ReaderTestError.readFailed }
        return assets
    }
    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset { fatalError("Not used") }
    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset { fatalError("Not used") }
    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {}
    func deleteReadingAsset(id: UUID) async throws {}
    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws {
        progressAttempts += 1
        if progressAttempts == 1 {
            let waiters = firstProgressWriteWaiters
            firstProgressWriteWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        if progressAttempts == 1, let firstProgressWriteFailsAfter {
            try? await Task.sleep(for: firstProgressWriteFailsAfter)
            throw ReaderTestError.writeFailed
        }
        progressWrites.append(position)
    }

    func waitForFirstProgressWrite() async {
        guard progressAttempts == 0 else { return }
        await withCheckedContinuation { continuation in
            firstProgressWriteWaiters.append(continuation)
        }
    }
    func progressWritesSnapshot() -> [ReaderPosition] { progressWrites }
    func readTags() async throws -> [Tag] { [] }
    func createTag(name: String) async throws -> Tag { fatalError("Not used") }
    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
}

private extension Article {
    static let empty = Article(id: UUID(), title: "", sourceName: "", contentChecksum: "", blocks: [])
}

private enum ReaderTestError: Error { case readFailed, writeFailed }

private final class ReaderRoutingArticleRepository: ArticleRepository, @unchecked Sendable {
    let articles: [UUID: Article]
    let progress: [UUID: ReaderPosition]
    let delayedID: UUID

    init(articles: [UUID: Article], progress: [UUID: ReaderPosition], delayedID: UUID) {
        self.articles = articles
        self.progress = progress
        self.delayedID = delayedID
    }
    func readArticle(id: UUID) async throws -> Article {
        if id == delayedID { try? await Task.sleep(for: .milliseconds(120)) }
        guard let article = articles[id] else { throw ReaderTestError.readFailed }
        return article
    }
    func readProgress(articleID: UUID) async throws -> ReaderPosition? { progress[articleID] }
}
