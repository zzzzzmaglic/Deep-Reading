import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class ReaderCoordinatorTests: XCTestCase {
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

        coordinator.queueProgress(visibleUTF16Location: 2)
        coordinator.queueProgress(visibleUTF16Location: 15)
        try await Task.sleep(for: .milliseconds(430))

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
    }

    func testDownScrollHidesChromeAfterDelayAndTapShowsIt() async throws {
        let coordinator = ReaderCoordinator(dependencies: ReaderDependencies(articleRepository: ReaderTestArticleRepository(article: .empty), readingAssetRepository: ReaderTestAssetRepository()), chromeHideDelay: .milliseconds(40))
        coordinator.handleScroll(direction: .down)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(coordinator.chromeIsVisible)

        coordinator.handleBodyTap()
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
        XCTAssertEqual(coordinator.assetFailure, .assetsFailed)
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
    private(set) var progressWrites: [ReaderPosition] = []

    init(assets: [ReadingAsset] = [], readError: Bool = false) {
        self.assets = assets
        self.readError = readError
    }
    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] {
        if readError { throw ReaderTestError.readFailed }
        return assets
    }
    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset { fatalError("Not used") }
    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset { fatalError("Not used") }
    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {}
    func deleteReadingAsset(id: UUID) async throws {}
    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws { progressWrites.append(position) }
    func readTags() async throws -> [Tag] { [] }
    func createTag(name: String) async throws -> Tag { fatalError("Not used") }
    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
}

private extension Article {
    static let empty = Article(id: UUID(), title: "", sourceName: "", contentChecksum: "", blocks: [])
}

private enum ReaderTestError: Error { case readFailed }
