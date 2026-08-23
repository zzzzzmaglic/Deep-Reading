import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class TagDetailCoordinatorTests: XCTestCase {
    func testNormalTagSelectionRemovesOnlyThatTagAssociation() async {
        let fixture = TagDetailFixture()
        let repository = TagDetailTestRepository(tags: [fixture.systemTag, fixture.normalTag], assets: [fixture.asset])
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.normalTag.id)
        coordinator.toggleSelection(fixture.asset.id)
        let succeeded = await coordinator.applySelectionAction()
        let removeRequests = await repository.removeTagRequests
        let deleteBatches = await repository.deleteAssetBatches

        XCTAssertTrue(succeeded)
        XCTAssertEqual(removeRequests, [(fixture.normalTag.id, [fixture.asset.id])])
        XCTAssertEqual(deleteBatches, [])
    }

    func testSystemTagSelectionDeletesTheAssetBatchAtomically() async {
        let fixture = TagDetailFixture()
        let repository = TagDetailTestRepository(tags: [fixture.systemTag], assets: [fixture.asset.with(tags: [fixture.systemTag])])
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.systemTag.id)
        coordinator.toggleSelection(fixture.asset.id)

        XCTAssertEqual(coordinator.selectionAction, .deleteAssets)
        XCTAssertTrue(await coordinator.applySelectionAction())
        let deleteBatches = await repository.deleteAssetBatches
        XCTAssertEqual(deleteBatches, [[fixture.asset.id]])
    }

    func testSourceRouteUsesTheAssetsAnchorAndKnowledgeOrigin() async {
        let fixture = TagDetailFixture()
        let repository = TagDetailTestRepository(tags: [fixture.normalTag], assets: [fixture.anchoredAsset])
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.normalTag.id)

        XCTAssertEqual(
            coordinator.routeToSource(for: fixture.anchoredAsset),
            ReaderRoute(articleID: fixture.articleID, anchorID: fixture.anchoredAsset.anchor?.id, origin: .knowledge)
        )
    }

    func testAssetsSortByNewestCreationDateFirst() async {
        let fixture = TagDetailFixture()
        let older = fixture.asset.with(createdAt: Date(timeIntervalSince1970: 10))
        let newer = fixture.anchoredAsset.with(createdAt: Date(timeIntervalSince1970: 20))
        let repository = TagDetailTestRepository(tags: [fixture.normalTag], assets: [older, newer])
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.normalTag.id)

        XCTAssertEqual(coordinator.assets.map(\.id), [newer.id, older.id])
    }

    func testStandaloneNoteForNormalTagPreselectsSystemAndCurrentTags() async {
        let fixture = TagDetailFixture()
        let repository = TagDetailTestRepository(tags: [fixture.systemTag, fixture.normalTag], assets: [])
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.normalTag.id)
        coordinator.beginStandaloneNote()

        XCTAssertEqual(coordinator.presentedDraft?.selectedTagIDs, [fixture.systemTag.id, fixture.normalTag.id])
    }

    func testStandaloneNoteForSystemTagPreselectsOnlyTheSystemTag() async {
        let fixture = TagDetailFixture()
        let repository = TagDetailTestRepository(tags: [fixture.systemTag, fixture.normalTag], assets: [])
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.systemTag.id)
        coordinator.beginStandaloneNote()

        XCTAssertEqual(coordinator.presentedDraft?.selectedTagIDs, [fixture.systemTag.id])
    }

    func testFailedMutationKeepsAssetsAndSelectionForRetry() async {
        let fixture = TagDetailFixture()
        let repository = TagDetailTestRepository(tags: [fixture.normalTag], assets: [fixture.asset], failRemoval: true)
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.normalTag.id)
        coordinator.toggleSelection(fixture.asset.id)

        XCTAssertFalse(await coordinator.applySelectionAction())
        XCTAssertEqual(coordinator.assets.map(\.id), [fixture.asset.id])
        XCTAssertEqual(coordinator.selectedAssetIDs, [fixture.asset.id])
    }

    func testConcurrentSelectionActionsSendOnlyOneRequest() async {
        let fixture = TagDetailFixture()
        let repository = TagDetailTestRepository(tags: [fixture.normalTag], assets: [fixture.asset], mutationDelay: .milliseconds(50))
        let coordinator = TagDetailCoordinator(repository: repository)

        await coordinator.load(tagID: fixture.normalTag.id)
        coordinator.toggleSelection(fixture.asset.id)
        let first = Task { @MainActor in await coordinator.applySelectionAction() }
        while !coordinator.isMutating { await Task.yield() }

        XCTAssertFalse(await coordinator.applySelectionAction())
        XCTAssertTrue(await first.value)
        let removeRequests = await repository.removeTagRequests
        XCTAssertEqual(removeRequests, [(fixture.normalTag.id, [fixture.asset.id])])
    }
}

private struct TagDetailFixture {
    let ownerID = UUID()
    let articleID = UUID()
    let systemTag: Tag
    let normalTag: Tag
    let asset: ReadingAsset
    let anchoredAsset: ReadingAsset

    init() {
        systemTag = Tag(id: UUID(), ownerID: ownerID, name: "摘录与思考", isSystem: true)
        normalTag = Tag(id: UUID(), ownerID: ownerID, name: "产品灵感", isSystem: false)
        asset = ReadingAsset(anchor: nil, noteContent: "独立笔记", tags: [systemTag, normalTag], createdAt: Date(timeIntervalSince1970: 10))
        anchoredAsset = ReadingAsset(
            articleID: articleID,
            anchor: TextAnchor(
                id: UUID(), assetID: UUID(), articleID: articleID,
                startBlockID: UUID(), endBlockID: UUID(),
                startUTF16Offset: 3, endUTF16Offset: 9,
                selectedText: "原文内容", contentChecksum: "checksum"
            ),
            noteContent: nil,
            tags: [normalTag],
            createdAt: Date(timeIntervalSince1970: 20)
        )
    }
}

private actor TagDetailTestRepository: ReadingAssetRepository {
    private var tags: [Tag]
    private var assets: [ReadingAsset]
    private let failRemoval: Bool
    private let mutationDelay: Duration?
    private(set) var removeTagRequests: [(UUID, [UUID])] = []
    private(set) var deleteAssetBatches: [[UUID]] = []

    init(tags: [Tag], assets: [ReadingAsset], failRemoval: Bool = false, mutationDelay: Duration? = nil) {
        self.tags = tags
        self.assets = assets
        self.failRemoval = failRemoval
        self.mutationDelay = mutationDelay
    }

    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] { assets }
    func readTags() async throws -> [Tag] { tags }
    func removeAssetsFromTag(tagID: UUID, assetIDs: [UUID]) async throws {
        if let mutationDelay { try await Task.sleep(for: mutationDelay) }
        if failRemoval { throw TagDetailTestError.removeFailed }
        removeTagRequests.append((tagID, assetIDs))
        assets = assets.map { asset in
            guard assetIDs.contains(asset.id) else { return asset }
            return asset.with(tags: asset.tags.filter { $0.id != tagID })
        }
    }
    func deleteReadingAssets(ids: [UUID]) async throws {
        deleteAssetBatches.append(ids)
        assets.removeAll { ids.contains($0.id) }
    }

    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset { fatalError("Not used") }
    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset { fatalError("Not used") }
    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {}
    func deleteReadingAsset(id: UUID) async throws {}
    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws {}
    func createTag(name: String) async throws -> Tag { fatalError("Not used") }
    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset { fatalError("Not used") }
}

private enum TagDetailTestError: Error { case removeFailed }

private extension ReadingAsset {
    func with(tags: [Tag]? = nil, createdAt: Date? = nil) -> ReadingAsset {
        ReadingAsset(
            id: id, ownerID: ownerID, articleID: articleID, anchor: anchor,
            noteContent: noteContent, tags: tags ?? self.tags, createdAt: createdAt ?? self.createdAt
        )
    }
}
