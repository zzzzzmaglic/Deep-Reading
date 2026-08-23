import Foundation
import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class TagManagementTests: XCTestCase {
    func testLockedTagCannotBeDeselected() {
        let fixture = AssetDraftTestFixtures()
        let controller = makeController(
            fixture: fixture,
            selectedTagIDs: [fixture.lockedTag.id],
            isEditing: true
        )

        controller.toggle(tag: fixture.lockedTag)

        XCTAssertTrue(controller.draft.selectedTagIDs.contains(fixture.lockedTag.id))
    }

    func testLoadedSystemTagIsAlwaysFirstAndSelected() async {
        let fixture = AssetDraftTestFixtures()
        let controller = AssetDraftController(
            draft: AssetDraft(anchor: fixture.highlight.anchor, articleID: fixture.articleID),
            repository: AssetDraftTestRepository(tags: [fixture.normalTag, fixture.lockedTag]),
            isEditing: true
        )

        await controller.loadAvailableTags()

        XCTAssertEqual(controller.availableTags.first?.id, fixture.lockedTag.id)
        XCTAssertTrue(controller.draft.selectedTagIDs.contains(fixture.lockedTag.id))
    }

    func testNewTagIsCreatedAndSelected() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        let controller = AssetDraftController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: repository,
            isEditing: true
        )

        let created = try await controller.addNewTag(name: "方法论")

        XCTAssertEqual(created.name, "方法论")
        XCTAssertTrue(controller.availableTags.contains(created))
        XCTAssertTrue(controller.draft.selectedTagIDs.contains(created.id))
    }

    func testDemoTagBootstrapCreatesOnlyMissingOwnerScopedTags() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        let controller = AssetDraftController(
            draft: AssetDraft(asset: fixture.highlight, noteContent: nil, selectedTagIDs: [fixture.lockedTag.id]),
            repository: repository,
            isEditing: true
        )

        await controller.loadAvailableTags(ensuring: ["产品灵感", "时间管理", "产品灵感"])

        let createdTagNames = await repository.createdTagNames
        XCTAssertEqual(createdTagNames, ["产品灵感", "时间管理"])
        XCTAssertEqual(
            controller.availableTags.filter { ["产品灵感", "时间管理"].contains($0.name) }.map(\.name).sorted(),
            ["产品灵感", "时间管理"].sorted()
        )
    }

    func testConcurrentTagCreationIsSingleFlight() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags, createTagDelay: .milliseconds(80))
        let controller = AssetDraftController(
            draft: AssetDraft(asset: fixture.highlight, noteContent: nil, selectedTagIDs: [fixture.lockedTag.id]),
            repository: repository,
            isEditing: true
        )

        async let first: Tag = controller.addNewTag(name: "方法论")
        try await Task.sleep(for: .milliseconds(10))
        async let second: Tag = controller.addNewTag(name: "方法论")
        _ = try? await (first, second)

        let createdNames = await repository.createdTagNames
        XCTAssertEqual(createdNames, ["方法论"])
    }

    func testViewModeTagConfirmationImmediatelyUsesSetAssetTags() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        var didRefreshReaderAssets = false
        let controller = AssetDraftController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: repository,
            isEditing: false,
            onSuccessfulTagUpdate: { didRefreshReaderAssets = true }
        )
        controller.toggle(tag: fixture.normalTag)

        try await controller.confirmTags()

        let requests = await repository.setTagRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.assetID, fixture.highlight.id)
        XCTAssertEqual(Set(requests.first?.tagIDs ?? []), [fixture.lockedTag.id, fixture.normalTag.id])
        let saveRequests = await repository.saveRequests
        XCTAssertTrue(saveRequests.isEmpty)
        XCTAssertTrue(didRefreshReaderAssets)
    }

    func testEditingModeTagConfirmationKeepsChangesDraftedUntilSave() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        let controller = AssetDraftController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: repository,
            isEditing: true
        )
        controller.toggle(tag: fixture.normalTag)

        try await controller.confirmTags()

        XCTAssertTrue(controller.draft.selectedTagIDs.contains(fixture.normalTag.id))
        XCTAssertTrue(controller.hasUnsavedChanges)
        let tagRequests = await repository.setTagRequests
        let saveRequests = await repository.saveRequests
        XCTAssertTrue(tagRequests.isEmpty)
        XCTAssertTrue(saveRequests.isEmpty)
    }

    private func makeController(
        fixture: AssetDraftTestFixtures,
        selectedTagIDs: Set<UUID>,
        isEditing: Bool
    ) -> AssetDraftController {
        AssetDraftController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: selectedTagIDs
            ),
            repository: AssetDraftTestRepository(tags: fixture.tags),
            isEditing: isEditing
        )
    }
}
