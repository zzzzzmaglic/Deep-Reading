import Foundation
import UIKit
import XCTest
@testable import DeepReadingVisualPrototype

@MainActor
final class AssetDraftControllerTests: XCTestCase {
    func testAssetCardQuoteDisplayUsesTheAnchorTextWithoutDecorationMarks() {
        XCTAssertEqual(
            ReadingAssetCard.quoteDisplayText("像万有引力一样"),
            "像万有引力一样"
        )
    }

    func testLinkedAssetQuoteViewStateUsesTheShared294PointCenteredTextContainer() {
        let background = ReadingAssetCardContentLayout.linkedQuoteBackground
        let text = ReadingAssetCardContentLayout.linkedQuoteText

        XCTAssertEqual(background.width, 323)
        XCTAssertEqual(background.height, 93)
        XCTAssertEqual(background.xOffset, 11)
        XCTAssertEqual(background.yOffset, 11)

        XCTAssertEqual(text.width, 294)
        XCTAssertEqual(text.height, 76)
        XCTAssertEqual(text.xOffset, 25.5)
        XCTAssertEqual(text.yOffset, 25)
        XCTAssertEqual(text.lineLimit, 3)
    }

    func testLinkedNoteEditStateMovesOnlyItsTextBoxesWithoutMovingTheQuoteBackground() {
        let quoteBackground = ReadingAssetCardContentLayout.linkedQuoteBackground
        let quote = ReadingAssetCardContentLayout.linkedQuoteTextEditing
        let note = ReadingAssetCardContentLayout.linkedNoteEditing

        XCTAssertEqual(quoteBackground.xOffset, 11)
        XCTAssertEqual(quoteBackground.yOffset, 11)
        XCTAssertEqual(quoteBackground.width, 323)
        XCTAssertEqual(quote.width, 294)
        XCTAssertEqual(quote.xOffset, 25.5)
        XCTAssertEqual(quote.yOffset, 25)
        XCTAssertEqual(note.width, 308)
        XCTAssertEqual(note.xOffset, 18.5)
        XCTAssertEqual(note.yOffset, 116)
    }

    func testNewAnchoredDraftUsesTheSame294PointQuoteContainerInEditState() {
        let quote = ReadingAssetCard.quoteTextLayout(
            isEditing: true,
            hasAnchor: true
        )

        XCTAssertEqual(quote.width, 294)
        XCTAssertEqual(quote.xOffset, 25.5)
        XCTAssertEqual(quote.yOffset, 25)
    }

    func testLinkedNoteUsesJustifiedNoteTextInBothCardStates() {
        XCTAssertEqual(
            AssetEditorView.noteTextAlignment(hasAnchor: true),
            NSTextAlignment.justified
        )
        XCTAssertEqual(
            AssetEditorView.noteTextAlignment(hasAnchor: false),
            NSTextAlignment.left
        )
    }

    func testEmptyLinkedNotePlaceholderUsesTheFirstLineOfTheNoteTextContainer() {
        let placeholder = ReadingAssetCard.placeholderNoteLayout(hasAnchor: true)

        XCTAssertEqual(placeholder.width, 308)
        XCTAssertEqual(placeholder.height, ReadingAssetCardContentLayout.noteLineHeight)
        XCTAssertEqual(placeholder.xOffset, 18.5)
        XCTAssertEqual(placeholder.yOffset, 116)
    }

    func testEditorMovesTheCursorToTheEndOnlyForARequestedViewToEditTransition() {
        let content = "已有笔记"

        XCTAssertEqual(
            AssetEditorView.cursorRange(
                for: content,
                placingAtEnd: true
            ),
            NSRange(location: (content as NSString).length, length: 0)
        )
        XCTAssertEqual(
            AssetEditorView.cursorRange(
                for: content,
                placingAtEnd: false
            ),
            NSRange(location: 0, length: 0)
        )
    }

    func testStandaloneNoteUsesTheSameTopAlignedContentLayoutInViewAndEditStates() {
        let layout = ReadingAssetCardContentLayout.standaloneNote

        XCTAssertEqual(layout.width, 305)
        XCTAssertEqual(layout.height, 310)
        XCTAssertEqual(layout.xOffset, 20)
        XCTAssertEqual(layout.yOffset, 24)
    }

    func testAssetCardUsesOneStableHeightAndActionRowAcrossViewAndEditStates() {
        XCTAssertEqual(ReadingAssetCardContentLayout.cardHeight, 400)
        XCTAssertEqual(ReadingAssetCardContentLayout.actionRowY, 337)
    }

    func testLinkedNoteViewLayoutMatchesEditStateGeometryAndTypography() {
        let note = ReadingAssetCardContentLayout.linkedNote

        XCTAssertEqual(note.width, 308)
        XCTAssertEqual(note.height, 220)
        XCTAssertEqual(note.xOffset, 18.5)
        XCTAssertEqual(note.yOffset, 116)
        XCTAssertEqual(ReadingAssetCardContentLayout.textSize, 14)
        XCTAssertEqual(ReadingAssetCardContentLayout.quoteLineHeight, 24)
        XCTAssertEqual(ReadingAssetCardContentLayout.noteLineHeight, 20)
    }

    func testAddingNoteConvertsHighlightWithoutChangingAssetIdentity() {
        let fixture = AssetDraftTestFixtures()
        let draft = AssetDraft(
            asset: fixture.highlight,
            noteContent: nil,
            selectedTagIDs: [fixture.lockedTag.id]
        )

        let updated = draft.with(noteContent: "我的想法")

        XCTAssertEqual(updated.kind, .linkedNote)
        XCTAssertEqual(updated.assetID, fixture.highlight.id)
    }

    func testClearingLinkedNoteReturnsToHighlightWithoutChangingAssetIdentity() {
        let fixture = AssetDraftTestFixtures()
        let draft = AssetDraft(
            asset: fixture.linkedNote,
            noteContent: fixture.linkedNote.noteContent,
            selectedTagIDs: [fixture.lockedTag.id]
        )

        let updated = draft.with(noteContent: "   \n")

        XCTAssertEqual(updated.kind, .highlight)
        XCTAssertEqual(updated.assetID, fixture.linkedNote.id)
        XCTAssertEqual(updated.anchor?.selectedText, fixture.linkedNote.anchor?.selectedText)
    }

    func testEditingTagChangesStayInDraftUntilSaveReadingAsset() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        let controller = makeController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: repository,
            isEditing: true
        )

        controller.toggle(tag: fixture.normalTag)

        XCTAssertTrue(controller.draft.selectedTagIDs.contains(fixture.normalTag.id))
        XCTAssertTrue(controller.hasUnsavedChanges)
        let requestsBeforeSave = await repository.saveRequests
        let tagRequestsBeforeSave = await repository.setTagRequests
        XCTAssertTrue(requestsBeforeSave.isEmpty)
        XCTAssertTrue(tagRequestsBeforeSave.isEmpty)

        try await controller.save()

        let requests = await repository.saveRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.assetID, fixture.highlight.id)
        XCTAssertEqual(Set(requests.first?.tagIDs ?? []), [fixture.lockedTag.id, fixture.normalTag.id])
        let tagRequestsAfterSave = await repository.setTagRequests
        XCTAssertTrue(tagRequestsAfterSave.isEmpty)
    }

    func testStandaloneDraftSaveUsesCreateStandaloneNoteWithTags() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        let controller = makeController(
            draft: AssetDraft(
                anchor: nil,
                articleID: fixture.articleID,
                noteContent: "独立想法",
                selectedTagIDs: [fixture.lockedTag.id, fixture.normalTag.id]
            ),
            repository: repository,
            isEditing: true
        )

        try await controller.save()

        let requests = await repository.standaloneSaveRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.articleID, fixture.articleID)
        XCTAssertEqual(requests.first?.noteContent, "独立想法")
        XCTAssertEqual(Set(requests.first?.tagIDs ?? []), [fixture.lockedTag.id, fixture.normalTag.id])
        let saveRequests = await repository.saveRequests
        XCTAssertTrue(saveRequests.isEmpty)
    }

    func testEmptyAnchoredDraftSaveCreatesPureHighlightAndCloses() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        var successfulSaveCount = 0
        let controller = makeController(
            draft: AssetDraft(
                anchor: fixture.highlight.anchor,
                articleID: fixture.articleID,
                noteContent: "  \n  "
            ),
            repository: repository,
            isEditing: true,
            onSuccessfulSave: { successfulSaveCount += 1 }
        )

        try await controller.save()

        let createdHighlights = await repository.createdHighlightIDs
        let standaloneRequests = await repository.standaloneSaveRequests
        XCTAssertEqual(createdHighlights.count, 1)
        XCTAssertTrue(standaloneRequests.isEmpty)
        XCTAssertEqual(controller.draft.kind, .highlight)
        XCTAssertEqual(successfulSaveCount, 1)
        XCTAssertNil(controller.operationError)
    }

    func testFirstAnchoredDraftSaveLetsBackendProvisionLockedSystemTag() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(
            tags: [fixture.normalTag],
            systemTagCreatedByHighlight: fixture.lockedTag
        )
        let controller = makeController(
            draft: AssetDraft(
                anchor: fixture.highlight.anchor,
                articleID: fixture.articleID,
                noteContent: ""
            ),
            repository: repository,
            isEditing: true
        )

        try await controller.save()

        let createdHighlights = await repository.createdHighlightIDs
        let saveRequests = await repository.saveRequests
        XCTAssertEqual(createdHighlights.count, 1)
        XCTAssertEqual(saveRequests.count, 1)
        XCTAssertEqual(saveRequests[0].tagIDs, [fixture.lockedTag.id])
        XCTAssertTrue(controller.draft.selectedTagIDs.contains(fixture.lockedTag.id))
    }

    func testEmptyStandaloneDraftSaveCreatesNothingAndCloses() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        var successfulSaveCount = 0
        let controller = makeController(
            draft: AssetDraft(
                anchor: nil,
                articleID: fixture.articleID,
                noteContent: " \n "
            ),
            repository: repository,
            isEditing: true,
            onSuccessfulSave: { successfulSaveCount += 1 }
        )

        try await controller.save()

        let standaloneRequests = await repository.standaloneSaveRequests
        let createdHighlights = await repository.createdHighlightIDs
        let saveRequests = await repository.saveRequests
        XCTAssertTrue(standaloneRequests.isEmpty)
        XCTAssertTrue(createdHighlights.isEmpty)
        XCTAssertTrue(saveRequests.isEmpty)
        XCTAssertEqual(successfulSaveCount, 1)
        XCTAssertNil(controller.operationError)
    }

    func testNewLinkedNoteSaveIncludesLockedSystemTagBeforeTagSheetIsOpened() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        let controller = makeController(
            draft: AssetDraft(anchor: fixture.highlight.anchor, articleID: fixture.articleID, noteContent: "新的想法"),
            repository: repository,
            isEditing: true
        )

        try await controller.save()

        let requests = await repository.saveRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(Set(requests[0].tagIDs), [fixture.lockedTag.id])
    }

    func testNewLinkedNoteLoadsLockedSystemTagAsAnInitialBaseline() async {
        let fixture = AssetDraftTestFixtures()
        let controller = makeController(
            draft: AssetDraft(anchor: fixture.highlight.anchor, articleID: fixture.articleID, noteContent: "新的想法"),
            repository: AssetDraftTestRepository(tags: fixture.tags),
            isEditing: true
        )

        await controller.loadAvailableTags()

        XCTAssertTrue(controller.draft.selectedTagIDs.contains(fixture.lockedTag.id))
        XCTAssertFalse(controller.hasUnsavedChanges)
    }

    func testRetryAfterLinkedNoteSaveFailureDoesNotCreateSecondHighlight() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags, failNextSave: true)
        let controller = makeController(
            draft: AssetDraft(anchor: fixture.highlight.anchor, articleID: fixture.articleID, noteContent: "新的想法"),
            repository: repository,
            isEditing: true
        )

        await XCTAssertThrowsErrorAsync { try await controller.save() }
        try await controller.save()

        let createdHighlights = await repository.createdHighlightIDs
        let saveRequests = await repository.saveRequests
        XCTAssertEqual(createdHighlights.count, 1)
        XCTAssertEqual(saveRequests.count, 1)
        XCTAssertEqual(saveRequests[0].assetID, createdHighlights[0])
    }

    func testConcurrentSaveCallsAreSingleFlight() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags, saveDelay: .milliseconds(80))
        let controller = makeController(
            draft: AssetDraft(asset: fixture.highlight, noteContent: "更新", selectedTagIDs: [fixture.lockedTag.id]),
            repository: repository,
            isEditing: true
        )

        async let first: Void = controller.save()
        try await Task.sleep(for: .milliseconds(10))
        async let second: Void = controller.save()
        _ = try? await (first, second)

        let requests = await repository.saveRequests
        XCTAssertEqual(requests.count, 1)
    }

    func testConcurrentDeleteCallsAreSingleFlight() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags, deleteDelay: .milliseconds(80))
        let controller = makeController(
            draft: AssetDraft(asset: fixture.highlight, noteContent: nil, selectedTagIDs: [fixture.lockedTag.id]),
            repository: repository,
            isEditing: false
        )

        async let first: Void = controller.delete()
        try await Task.sleep(for: .milliseconds(10))
        async let second: Void = controller.delete()
        _ = try? await (first, second)

        let deletedAssetIDs = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDs, [fixture.highlight.id])
    }

    func testSuccessfulDeleteNotifiesCardToCloseAndRefresh() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        var successfulDeleteIDs: [UUID] = []
        let controller = makeController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: repository,
            isEditing: false,
            onSuccessfulDelete: { successfulDeleteIDs.append($0) }
        )

        try await controller.delete()

        let deletedAssetIDs = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDs, [fixture.highlight.id])
        XCTAssertEqual(successfulDeleteIDs, [fixture.highlight.id])
    }

    func testFailedDeleteKeepsCardOpenAndCanBeRetried() async throws {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags, failNextDelete: true)
        var successfulDeleteIDs: [UUID] = []
        let controller = makeController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: repository,
            isEditing: false,
            onSuccessfulDelete: { successfulDeleteIDs.append($0) }
        )

        await XCTAssertThrowsErrorAsync {
            try await controller.delete()
        }

        XCTAssertTrue(successfulDeleteIDs.isEmpty)
        let deletedAssetIDsAfterFailure = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDsAfterFailure, [])

        try await controller.delete()

        let deletedAssetIDsAfterRetry = await repository.deletedAssetIDs
        XCTAssertEqual(deletedAssetIDsAfterRetry, [fixture.highlight.id])
        XCTAssertEqual(successfulDeleteIDs, [fixture.highlight.id])
    }

    func testTagOnlyDraftChangesDoNotRequestDiscardConfirmation() {
        let fixture = AssetDraftTestFixtures()
        let repository = AssetDraftTestRepository(tags: fixture.tags)
        let controller = makeController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: repository,
            isEditing: true
        )
        controller.toggle(tag: fixture.normalTag)

        XCTAssertEqual(controller.dismissalDecision, .close)

        controller.discard()

        XCTAssertFalse(controller.hasUnsavedChanges)
        XCTAssertFalse(controller.draft.selectedTagIDs.contains(fixture.normalTag.id))
        XCTAssertEqual(controller.dismissalDecision, .close)
    }

    func testTypingThenClearingNoteDoesNotRequestDiscardConfirmation() {
        let fixture = AssetDraftTestFixtures()
        let controller = makeController(
            draft: AssetDraft(
                asset: fixture.highlight,
                noteContent: nil,
                selectedTagIDs: [fixture.lockedTag.id]
            ),
            repository: AssetDraftTestRepository(tags: fixture.tags),
            isEditing: true
        )

        controller.setNoteContent("待放弃的草稿")
        XCTAssertEqual(controller.dismissalDecision, .confirmDiscard)

        controller.setNoteContent(" \n ")
        XCTAssertEqual(controller.dismissalDecision, .close)
    }

    func testStandaloneNoteFollowsTheSameDiscardRule() {
        let fixture = AssetDraftTestFixtures()
        let controller = makeController(
            draft: AssetDraft(anchor: nil, articleID: fixture.articleID),
            repository: AssetDraftTestRepository(tags: fixture.tags),
            isEditing: true
        )

        controller.setNoteContent("独立笔记")
        XCTAssertEqual(controller.dismissalDecision, .confirmDiscard)

        controller.setNoteContent("")
        XCTAssertEqual(controller.dismissalDecision, .close)
    }

    private func makeController(
        draft: AssetDraft,
        repository: AssetDraftTestRepository,
        isEditing: Bool,
        onSuccessfulSave: @escaping () -> Void = {},
        onSuccessfulDelete: @escaping (UUID) -> Void = { _ in }
    ) -> AssetDraftController {
        AssetDraftController(
            draft: draft,
            repository: repository,
            isEditing: isEditing,
            onSuccessfulSave: onSuccessfulSave,
            onSuccessfulDelete: onSuccessfulDelete
        )
    }
}

struct AssetDraftTestFixtures {
    let articleID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    let lockedTag = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
        ownerID: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
        name: "摘录与思考",
        isSystem: true
    )
    let normalTag = Tag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
        ownerID: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
        name: "商业化",
        isSystem: false
    )

    var tags: [Tag] { [lockedTag, normalTag] }

    var highlight: ReadingAsset {
        let assetID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
        return ReadingAsset(
            id: assetID,
            articleID: articleID,
            anchor: TextAnchor(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
                assetID: assetID,
                articleID: articleID,
                startBlockID: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
                endBlockID: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
                startUTF16Offset: 2,
                endUTF16Offset: 8,
                selectedText: "阅读的划线",
                contentChecksum: "checksum"
            ),
            noteContent: nil,
            tags: tags
        )
    }

    var linkedNote: ReadingAsset {
        ReadingAsset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            articleID: articleID,
            anchor: highlight.anchor,
            noteContent: "已有想法",
            tags: tags
        )
    }
}

actor AssetDraftTestRepository: ReadingAssetRepository {
    struct SaveRequest {
        let assetID: UUID
        let noteContent: String?
        let tagIDs: [UUID]
    }

    struct StandaloneSaveRequest {
        let articleID: UUID?
        let noteContent: String
        let tagIDs: [UUID]
    }

    private var tags: [Tag]
    private var shouldFailNextDelete: Bool
    private var shouldFailNextSave: Bool
    private let saveDelay: Duration?
    private let deleteDelay: Duration?
    private let createTagDelay: Duration?
    private let systemTagCreatedByHighlight: Tag?
    private(set) var saveRequests: [SaveRequest] = []
    private(set) var standaloneSaveRequests: [StandaloneSaveRequest] = []
    private(set) var setTagRequests: [(assetID: UUID, tagIDs: [UUID])] = []
    private(set) var deletedAssetIDs: [UUID] = []
    private(set) var createdHighlightIDs: [UUID] = []
    private(set) var createdTagNames: [String] = []
    private var assetsByID: [UUID: ReadingAsset] = [:]

    init(
        tags: [Tag],
        failNextDelete: Bool = false,
        failNextSave: Bool = false,
        saveDelay: Duration? = nil,
        deleteDelay: Duration? = nil,
        createTagDelay: Duration? = nil,
        systemTagCreatedByHighlight: Tag? = nil
    ) {
        self.tags = tags
        shouldFailNextDelete = failNextDelete
        shouldFailNextSave = failNextSave
        self.saveDelay = saveDelay
        self.deleteDelay = deleteDelay
        self.createTagDelay = createTagDelay
        self.systemTagCreatedByHighlight = systemTagCreatedByHighlight
    }

    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] { [] }
    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset {
        let id = UUID()
        createdHighlightIDs.append(id)
        if let systemTagCreatedByHighlight,
           !tags.contains(where: { $0.id == systemTagCreatedByHighlight.id }) {
            tags.append(systemTagCreatedByHighlight)
        }
        let asset = ReadingAsset(id: id, articleID: articleID, anchor: anchor, noteContent: nil, tags: tags)
        assetsByID[id] = asset
        return asset
    }
    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset { throw TestError.unsupported }
    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset { throw TestError.unsupported }
    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws {}

    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {
        setTagRequests.append((assetID, tagIDs))
    }

    func deleteReadingAsset(id: UUID) async throws {
        if let deleteDelay { try? await Task.sleep(for: deleteDelay) }
        if shouldFailNextDelete {
            shouldFailNextDelete = false
            throw TestError.deleteFailed
        }
        deletedAssetIDs.append(id)
    }

    func readTags() async throws -> [Tag] { tags }

    func createTag(name: String) async throws -> Tag {
        if let createTagDelay { try? await Task.sleep(for: createTagDelay) }
        createdTagNames.append(name)
        let tag = Tag(id: UUID(), ownerID: tags[0].ownerID, name: name, isSystem: false)
        tags.append(tag)
        return tag
    }

    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset {
        if let saveDelay { try? await Task.sleep(for: saveDelay) }
        if shouldFailNextSave {
            shouldFailNextSave = false
            throw TestError.saveFailed
        }
        saveRequests.append(SaveRequest(assetID: id, noteContent: noteContent, tagIDs: tagIDs))
        let existing = assetsByID[id]
        let saved = ReadingAsset(
            id: id,
            articleID: existing?.articleID,
            anchor: existing?.anchor,
            noteContent: noteContent,
            tags: tags.filter { tagIDs.contains($0.id) }
        )
        assetsByID[id] = saved
        return saved
    }

    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset {
        standaloneSaveRequests.append(StandaloneSaveRequest(articleID: articleID, noteContent: noteContent, tagIDs: tagIDs))
        return ReadingAsset(articleID: articleID, anchor: nil, noteContent: noteContent)
    }

    enum TestError: Error {
        case unsupported
        case deleteFailed
        case saveFailed
    }
}

func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected an error.", file: file, line: line)
    } catch {}
}
