import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class CollectionDetailCoordinatorTests: XCTestCase {
    func testNormalCollectionAllowsSelectionAndRemovalUsesOneRepositoryRPC() async {
        let collection = makeCollection(name: "深度阅读")
        let first = makeArticle(title: "第一篇")
        let second = makeArticle(title: "第二篇")
        let repository = CollectionTestKnowledgeRepository(collection: collection, articles: [first, second])
        let coordinator = CollectionDetailCoordinator(repository: repository)

        await coordinator.load(collectionID: collection.id)
        coordinator.toggleSelection(articleID: first.id)

        XCTAssertEqual(coordinator.selectedArticleIDs, [first.id])
        let removed = await coordinator.removeSelection()
        XCTAssertTrue(removed)
        let removalCalls = await repository.removalCalls()
        XCTAssertEqual(removalCalls, [[first.id]])
        XCTAssertEqual(coordinator.articles.map(\.id), [second.id])
        XCTAssertTrue(coordinator.selectedArticleIDs.isEmpty)
    }

    func testSystemPastTweetsCannotEnterSelection() async {
        let collection = makeCollection(name: "往期推文", isSystem: true)
        let article = makeArticle(title: "锁定文章")
        let repository = CollectionTestKnowledgeRepository(collection: collection, articles: [article])
        let coordinator = CollectionDetailCoordinator(repository: repository)

        await coordinator.load(collectionID: collection.id)
        coordinator.toggleSelection(articleID: article.id)

        XCTAssertTrue(coordinator.selectedArticleIDs.isEmpty)
    }

    func testRemovalFailureKeepsListAndSelection() async {
        let collection = makeCollection(name: "深度阅读")
        let article = makeArticle(title: "保留文章")
        let repository = CollectionTestKnowledgeRepository(collection: collection, articles: [article], shouldFailRemoval: true)
        let coordinator = CollectionDetailCoordinator(repository: repository)

        await coordinator.load(collectionID: collection.id)
        coordinator.toggleSelection(articleID: article.id)

        let removed = await coordinator.removeSelection()
        XCTAssertFalse(removed)
        XCTAssertEqual(coordinator.articles.map(\.id), [article.id])
        XCTAssertEqual(coordinator.selectedArticleIDs, [article.id])
    }

    func testConcurrentSecondRemovalReturnsFalse() async {
        let collection = makeCollection(name: "深度阅读")
        let article = makeArticle(title: "慢速文章")
        let repository = CollectionTestKnowledgeRepository(collection: collection, articles: [article], removalDelay: .milliseconds(50))
        let coordinator = CollectionDetailCoordinator(repository: repository)

        await coordinator.load(collectionID: collection.id)
        coordinator.toggleSelection(articleID: article.id)
        let firstRequest = Task { @MainActor in await coordinator.removeSelection() }
        while !coordinator.isRemoving { await Task.yield() }

        let concurrentResult = await coordinator.removeSelection()
        let firstResult = await firstRequest.value
        XCTAssertFalse(concurrentResult)
        XCTAssertTrue(firstResult)
    }

    func testLockedCollectionDoesNotAttachHorizontalSelectionGesture() {
        XCTAssertFalse(CollectionDetailScreenPolicy.attachesSelectionGesture(isLockedCollection: true))
        XCTAssertTrue(CollectionDetailScreenPolicy.attachesSelectionGesture(isLockedCollection: false))
    }

    func testDetailChromeRendersAboveTopProgressiveEdge() {
        XCTAssertEqual(CollectionDetailScreenPolicy.topLayerOrder, [.progressiveEdge, .chrome])
    }

    private func makeCollection(name: String, isSystem: Bool = false) -> KnowledgeCollection {
        KnowledgeCollection(id: UUID(), name: name, description: nil, isSystem: isSystem, visibleArticleCount: 2)
    }

    private func makeArticle(title: String) -> KnowledgeArticlePreview {
        KnowledgeArticlePreview(
            id: UUID(), title: title, sourceName: "来源", coverAssetName: "KnowledgeCoverPlaceholder",
            cognitiveDimension: "方法论", publishedAt: .distantPast, readingAssetCount: 0
        )
    }
}

private actor CollectionTestKnowledgeRepository: KnowledgeBaseRepository {
    private let collection: KnowledgeCollection
    private var articles: [KnowledgeArticlePreview]
    private let shouldFailRemoval: Bool
    private let removalDelay: Duration?
    private var recordedRemovalCalls: [[UUID]] = []

    init(collection: KnowledgeCollection, articles: [KnowledgeArticlePreview], shouldFailRemoval: Bool = false, removalDelay: Duration? = nil) {
        self.collection = collection
        self.articles = articles
        self.shouldFailRemoval = shouldFailRemoval
        self.removalDelay = removalDelay
    }

    func readHome() async throws -> KnowledgeHomeSnapshot { .init(collections: [collection], tags: []) }
    func readCollection(id: UUID) async throws -> KnowledgeCollection { collection }
    func readCollectionArticles(collectionID: UUID) async throws -> [KnowledgeArticlePreview] { articles }
    func readArticleTitles(ids: Set<UUID>) async throws -> [UUID: String] { [:] }
    func removeArticlesFromCollection(collectionID: UUID, articleIDs: [UUID]) async throws {
        if let removalDelay { try await Task.sleep(for: removalDelay) }
        if shouldFailRemoval { throw CollectionTestError.removalFailed }
        recordedRemovalCalls.append(articleIDs)
        articles.removeAll { articleIDs.contains($0.id) }
    }

    func removalCalls() -> [[UUID]] { recordedRemovalCalls }
}

private enum CollectionTestError: Error { case removalFailed }
