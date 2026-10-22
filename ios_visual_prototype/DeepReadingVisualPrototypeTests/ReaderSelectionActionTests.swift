import Foundation
import UIKit
import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class ReaderSelectionActionTests: XCTestCase {
    private let articleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let blockID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!

    func testHighlightCreatesOneAssetUsingSelectedTextFromUTF16Range() async throws {
        let repository = SelectionTestAssetRepository()
        let coordinator = try await makeCoordinator(repository: repository)

        try await coordinator.performSelection(
            selectedWorldRange(),
            action: .highlight
        )

        let createdHighlights = await repository.createdHighlights
        XCTAssertEqual(createdHighlights.count, 1)
        XCTAssertEqual(createdHighlights.first?.anchor?.selectedText, "世界，和物")
        XCTAssertEqual(coordinator.assets.count, 1)
    }

    func testHighlightCreationFailureIsVisibleAndRetryCreatesOnce() async throws {
        let repository = SelectionTestAssetRepository()
        await repository.failNextHighlightCreation()
        let coordinator = try await makeCoordinator(repository: repository)

        do {
            try await coordinator.performSelection(
                selectedWorldRange(),
                action: .highlight
            )
            XCTFail("Expected the failed highlight RPC to surface.")
        } catch {}

        XCTAssertEqual(coordinator.selectionFailure, .highlightCreationFailed)
        let failedCreationHighlights = await repository.createdHighlights
        XCTAssertTrue(failedCreationHighlights.isEmpty)

        coordinator.retryHighlightCreation()
        await waitForAsyncWork()

        let retriedHighlights = await repository.createdHighlights
        XCTAssertEqual(retriedHighlights.count, 1)
        XCTAssertNil(coordinator.selectionFailure)
    }

    func testRapidRepeatedHighlightRetryStartsOnlyOneCreateRPC() async throws {
        let repository = SelectionTestAssetRepository()
        await repository.failNextHighlightCreation()
        let coordinator = try await makeCoordinator(repository: repository)

        do {
            try await coordinator.performSelection(
                selectedWorldRange(),
                action: .highlight
            )
            XCTFail("Expected the initial highlight RPC to fail.")
        } catch {}

        await repository.pauseNextHighlightCreation()
        coordinator.retryHighlightCreation()
        await repository.waitUntilHighlightCreationStarts()
        coordinator.retryHighlightCreation()

        await repository.releasePausedHighlightCreation()
        await waitForAsyncWork()

        let createdHighlights = await repository.createdHighlights
        XCTAssertEqual(createdHighlights.count, 1)
        XCTAssertNil(coordinator.selectionFailure)
    }

    func testRefreshFailureAfterSuccessfulHighlightDoesNotRetryTheCreateRPC() async throws {
        let repository = SelectionTestAssetRepository()
        let coordinator = try await makeCoordinator(repository: repository)
        await waitForAsyncWork()
        await repository.failNextAssetRead()

        try await coordinator.performSelection(
            selectedWorldRange(),
            action: .highlight
        )

        let createdHighlights = await repository.createdHighlights
        XCTAssertEqual(createdHighlights.count, 1)
        XCTAssertNil(coordinator.selectionFailure)
        XCTAssertEqual(coordinator.assetFailure, .assetsFailed)

        coordinator.retryHighlightCreation()
        await waitForAsyncWork()
        let highlightsAfterRetryAttempt = await repository.createdHighlights
        XCTAssertEqual(highlightsAfterRetryAttempt.count, 1)

        await coordinator.refreshAssets()
        XCTAssertNil(coordinator.assetFailure)
        XCTAssertEqual(coordinator.assets.count, 1)
    }

    func testOpenAssetCardCreatesAnchoredDraftWithoutPersistingAnAsset() async throws {
        let repository = SelectionTestAssetRepository()
        let coordinator = try await makeCoordinator(repository: repository)

        try await coordinator.performSelection(
            selectedWorldRange(),
            action: .openAssetCard
        )

        let createdHighlights = await repository.createdHighlights
        XCTAssertTrue(createdHighlights.isEmpty)
        XCTAssertEqual(coordinator.presentedAssetDraft?.articleID, articleID)
        XCTAssertEqual(coordinator.presentedAssetDraft?.anchor?.selectedText, "世界，和物")
        XCTAssertNil(coordinator.presentedAssetDraft?.noteContent)
    }

    func testCopyDoesNotCreateAnAssetOrDraft() async throws {
        let repository = SelectionTestAssetRepository()
        let coordinator = try await makeCoordinator(repository: repository)

        try await coordinator.performSelection(
            selectedWorldRange(),
            action: .copy
        )

        let createdHighlights = await repository.createdHighlights
        XCTAssertTrue(createdHighlights.isEmpty)
        XCTAssertNil(coordinator.presentedAssetDraft)
    }

    func testExplainWithAIDoesNotCreateAnAssetOrStartAWorkflow() async throws {
        let repository = SelectionTestAssetRepository()
        let coordinator = try await makeCoordinator(repository: repository)

        try await coordinator.performSelection(
            selectedWorldRange(),
            action: .explainWithAI
        )

        let createdHighlights = await repository.createdHighlights
        XCTAssertTrue(createdHighlights.isEmpty)
        XCTAssertNil(coordinator.presentedAssetDraft)
    }

    func testStandaloneNoteHasNoAnchorAndKeepsCurrentArticleScope() async throws {
        let coordinator = try await makeCoordinator(repository: SelectionTestAssetRepository())

        let draft = try XCTUnwrap(coordinator.beginStandaloneNote())

        XCTAssertNil(draft.anchor)
        XCTAssertEqual(draft.articleID, articleID)
    }

    func testLoadingANewRouteClearsTheDraftFromThePreviousArticle() async throws {
        let firstArticle = makeArticle()
        let secondArticleID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let secondArticle = Article(
            id: secondArticleID,
            title: "另一篇",
            sourceName: "测试来源",
            contentChecksum: "second-selection-checksum",
            blocks: [
                ArticleBlock(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
                    articleID: secondArticleID,
                    position: 0,
                    content: "另一篇文章正文",
                    kind: .paragraph
                ),
            ]
        )
        let coordinator = ReaderCoordinator(
            dependencies: ReaderDependencies(
                articleRepository: SelectionTestArticleRepository(articles: [
                    firstArticle.id: firstArticle,
                    secondArticle.id: secondArticle,
                ]),
                readingAssetRepository: SelectionTestAssetRepository()
            )
        )
        try await coordinator.load(route: ReaderRoute(articleID: firstArticle.id, anchorID: nil, origin: .feed))
        XCTAssertNotNil(coordinator.beginStandaloneNote())
        XCTAssertNotNil(coordinator.presentedAssetDraft)

        try await coordinator.load(route: ReaderRoute(articleID: secondArticle.id, anchorID: nil, origin: .feed))

        XCTAssertNil(coordinator.presentedAssetDraft)
    }

    func testActionsFromOldRouteAreIgnoredWhileNewRouteIsLoading() async throws {
        let firstArticle = makeArticle()
        let secondArticle = makeSecondArticle()
        let gate = SelectionRouteLoadGate()
        let repository = SelectionTestAssetRepository()
        await repository.failNextHighlightCreation()
        let coordinator = ReaderCoordinator(
            dependencies: ReaderDependencies(
                articleRepository: SelectionRouteGatedArticleRepository(
                    articles: [firstArticle.id: firstArticle, secondArticle.id: secondArticle],
                    blockedArticleID: secondArticle.id,
                    gate: gate
                ),
                readingAssetRepository: repository
            )
        )
        try await coordinator.load(route: ReaderRoute(articleID: firstArticle.id, anchorID: nil, origin: .feed))

        do {
            try await coordinator.performSelection(
                selectedWorldRange(),
                action: .highlight
            )
            XCTFail("Expected the first route's highlight creation to fail.")
        } catch {}

        let newRouteLoad = Task { @MainActor in
            try? await coordinator.load(
                route: ReaderRoute(articleID: secondArticle.id, anchorID: nil, origin: .feed)
            )
        }
        await gate.waitUntilBlockedReadStarts()

        try await coordinator.performSelection(
            selectedWorldRange(),
            action: .highlight
        )
        XCTAssertNil(coordinator.beginStandaloneNote())
        coordinator.retryHighlightCreation()
        await waitForAsyncWork()

        XCTAssertNil(coordinator.presentedAssetDraft)
        XCTAssertNil(coordinator.selectionFailure)
        let createdHighlights = await repository.createdHighlights
        XCTAssertTrue(createdHighlights.isEmpty)

        await gate.releaseBlockedRead()
        _ = await newRouteLoad.value
    }

    func testOldHighlightCompletionCannotRefillStateAfterNewRouteStarts() async throws {
        let firstArticle = makeArticle()
        let secondArticle = makeSecondArticle()
        let gate = SelectionRouteLoadGate()
        let repository = SelectionTestAssetRepository()
        let coordinator = ReaderCoordinator(
            dependencies: ReaderDependencies(
                articleRepository: SelectionRouteGatedArticleRepository(
                    articles: [firstArticle.id: firstArticle, secondArticle.id: secondArticle],
                    blockedArticleID: secondArticle.id,
                    gate: gate
                ),
                readingAssetRepository: repository
            )
        )
        try await coordinator.load(route: ReaderRoute(articleID: firstArticle.id, anchorID: nil, origin: .feed))

        await repository.pauseNextHighlightCreation()
        let oldHighlight = Task { @MainActor in
            try? await coordinator.performSelection(
                selectedWorldRange(),
                action: .highlight
            )
        }
        await repository.waitUntilHighlightCreationStarts()

        let newRouteLoad = Task { @MainActor in
            try? await coordinator.load(
                route: ReaderRoute(articleID: secondArticle.id, anchorID: nil, origin: .feed)
            )
        }
        await gate.waitUntilBlockedReadStarts()

        await repository.releasePausedHighlightCreation()
        _ = await oldHighlight.value

        XCTAssertTrue(coordinator.assets.isEmpty)
        XCTAssertNil(coordinator.presentedAssetDraft)
        XCTAssertNil(coordinator.selectionFailure)

        await gate.releaseBlockedRead()
        _ = await newRouteLoad.value
        await waitForAsyncWork()
        XCTAssertEqual(coordinator.article?.id, secondArticle.id)
        XCTAssertTrue(coordinator.assets.isEmpty)
    }

    func testStartingBodyDragClearsTheNativeSelectionBeforeReaderScrolls() {
        let article = makeArticle()
        let layout = ReaderTextLayout(article: article, image: nil)
        let readerTextView = ReaderTextView(
            layout: layout,
            highlights: [],
            documentRevision: ReaderTextDocumentRevision(
                articleID: article.id,
                contentChecksum: article.contentChecksum,
                highlights: []
            ),
            requestedScrollRequest: nil,
            onVisibleUTF16Location: { _ in },
            onScrollDirection: { _ in },
            onBodyTap: {},
            onInitialScrollApplied: {},
            selectedText: { try? layout.selectedText(for: $0) },
            normalizedSelection: layout.normalizedSourceSelection,
            isStandaloneLayoutSelection: layout.isStandaloneLayoutSelection,
            highlightedAnchorAt: { _ in nil },
            highlightedAnchorIntersecting: { _ in nil },
            highlightedAnchorRange: { _ in nil },
            onSelectionAction: { _, _ in },
            onHighlightedTextAction: { _, _ in },
            showsBottomEdgeEffect: true
        )
        let nativeCoordinator = readerTextView.makeCoordinator()
        let textView = UITextView()
        textView.attributedText = layout.attributedText
        textView.selectedRange = NSRange(location: 3, length: 5)

        nativeCoordinator.scrollViewWillBeginDragging(textView)

        XCTAssertEqual(textView.selectedRange, NSRange(location: 8, length: 0))
    }

    private func makeCoordinator(
        repository: SelectionTestAssetRepository
    ) async throws -> ReaderCoordinator {
        let article = makeArticle()
        let coordinator = ReaderCoordinator(
            dependencies: ReaderDependencies(
                articleRepository: SelectionTestArticleRepository(article: article),
                readingAssetRepository: repository
            )
        )
        try await coordinator.load(
            route: ReaderRoute(articleID: articleID, anchorID: nil, origin: .feed)
        )
        return coordinator
    }

    private func selectedWorldRange() -> NSRange {
        let layout = ReaderTextLayout(article: makeArticle(), image: nil)
        let source = layout.range(forBlockID: blockID)!
        return NSRange(location: source.location + 3, length: 5)
    }

    private func makeArticle() -> Article {
        Article(
            id: articleID,
            title: "",
            sourceName: "测试来源",
            contentChecksum: "selection-checksum",
            blocks: [
                ArticleBlock(
                    id: blockID,
                    articleID: articleID,
                    position: 0,
                    content: "你好，世界，和物理",
                    kind: .paragraph
                ),
            ]
        )
    }

    private func makeSecondArticle() -> Article {
        let articleID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        return Article(
            id: articleID,
            title: "另一篇",
            sourceName: "测试来源",
            contentChecksum: "second-selection-checksum",
            blocks: [
                ArticleBlock(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
                    articleID: articleID,
                    position: 0,
                    content: "另一篇文章正文",
                    kind: .paragraph
                ),
            ]
        )
    }

    private func waitForAsyncWork() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }
}

private final class SelectionTestArticleRepository: ArticleRepository, @unchecked Sendable {
    private let articles: [UUID: Article]

    init(article: Article) {
        articles = [article.id: article]
    }

    init(articles: [UUID: Article]) {
        self.articles = articles
    }

    func readArticle(id: UUID) async throws -> Article {
        guard let article = articles[id] else { throw SelectionTestRepositoryError.unsupported }
        return article
    }

    func readProgress(articleID: UUID) async throws -> ReaderPosition? {
        nil
    }
}

private actor SelectionTestAssetRepository: ReadingAssetRepository {
    private(set) var createdHighlights: [ReadingAsset] = []
    private var remainingHighlightCreateFailures = 0
    private var remainingAssetReadFailures = 0
    private var pausesNextHighlightCreation = false
    private var hasStartedHighlightCreation = false
    private var pausedHighlightCreationIsReleased = false
    private var highlightCreationStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var highlightCreationReleaseWaiters: [CheckedContinuation<Void, Never>] = []

    func failNextHighlightCreation() {
        remainingHighlightCreateFailures += 1
    }

    func failNextAssetRead() {
        remainingAssetReadFailures += 1
    }

    func pauseNextHighlightCreation() {
        pausesNextHighlightCreation = true
        hasStartedHighlightCreation = false
        pausedHighlightCreationIsReleased = false
    }

    func waitUntilHighlightCreationStarts() async {
        guard !hasStartedHighlightCreation else { return }
        await withCheckedContinuation { continuation in
            highlightCreationStartWaiters.append(continuation)
        }
    }

    func releasePausedHighlightCreation() {
        pausedHighlightCreationIsReleased = true
        let waiters = highlightCreationReleaseWaiters
        highlightCreationReleaseWaiters = []
        waiters.forEach { $0.resume() }
    }

    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] {
        if remainingAssetReadFailures > 0 {
            remainingAssetReadFailures -= 1
            throw SelectionTestRepositoryError.unsupported
        }
        return createdHighlights.filter { $0.associatedArticleID == articleID }
    }

    func createHighlight(
        articleID: UUID,
        anchor: TextAnchor,
        checksum: String
    ) async throws -> ReadingAsset {
        hasStartedHighlightCreation = true
        let startWaiters = highlightCreationStartWaiters
        highlightCreationStartWaiters = []
        startWaiters.forEach { $0.resume() }
        if pausesNextHighlightCreation {
            pausesNextHighlightCreation = false
            if !pausedHighlightCreationIsReleased {
                await withCheckedContinuation { continuation in
                    highlightCreationReleaseWaiters.append(continuation)
                }
            }
        }
        if remainingHighlightCreateFailures > 0 {
            remainingHighlightCreateFailures -= 1
            throw SelectionTestRepositoryError.unsupported
        }
        let asset = ReadingAsset(articleID: articleID, anchor: anchor, noteContent: nil)
        createdHighlights.append(asset)
        return asset
    }

    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset {
        throw SelectionTestRepositoryError.unsupported
    }

    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset {
        throw SelectionTestRepositoryError.unsupported
    }

    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {}

    func deleteReadingAsset(id: UUID) async throws {}

    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws {}

    func readTags() async throws -> [Tag] { [] }

    func createTag(name: String) async throws -> Tag {
        throw SelectionTestRepositoryError.unsupported
    }

    func saveReadingAsset(
        id: UUID,
        noteContent: String?,
        tagIDs: [UUID]
    ) async throws -> ReadingAsset {
        throw SelectionTestRepositoryError.unsupported
    }

    func createStandaloneNoteWithTags(
        articleID: UUID?,
        noteContent: String,
        tagIDs: [UUID]
    ) async throws -> ReadingAsset {
        throw SelectionTestRepositoryError.unsupported
    }
}

private final class SelectionRouteGatedArticleRepository: ArticleRepository, @unchecked Sendable {
    private let articles: [UUID: Article]
    private let blockedArticleID: UUID
    private let gate: SelectionRouteLoadGate

    init(articles: [UUID: Article], blockedArticleID: UUID, gate: SelectionRouteLoadGate) {
        self.articles = articles
        self.blockedArticleID = blockedArticleID
        self.gate = gate
    }

    func readArticle(id: UUID) async throws -> Article {
        if id == blockedArticleID {
            await gate.blockUntilReleased()
        }
        guard let article = articles[id] else { throw SelectionTestRepositoryError.unsupported }
        return article
    }

    func readProgress(articleID: UUID) async throws -> ReaderPosition? { nil }
}

private actor SelectionRouteLoadGate {
    private var blockedReadStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func blockUntilReleased() async {
        blockedReadStarted = true
        let waiters = startWaiters
        startWaiters = []
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilBlockedReadStarts() async {
        guard !blockedReadStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseBlockedRead() {
        let waiters = releaseWaiters
        releaseWaiters = []
        waiters.forEach { $0.resume() }
    }
}

private enum SelectionTestRepositoryError: Error {
    case unsupported
}
