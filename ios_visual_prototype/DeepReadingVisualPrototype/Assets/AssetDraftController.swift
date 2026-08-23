import Combine
import Foundation

enum AssetDraftDismissalDecision: Equatable {
    case close
    case confirmDiscard
}

enum AssetDraftControllerError: LocalizedError {
    case missingAssetID
    case operationInProgress

    var errorDescription: String? {
        switch self {
        case .missingAssetID:
            "阅读资产不存在。"
        case .operationInProgress:
            "操作正在进行，请稍候。"
        }
    }
}

/// Owns the mutable, local representation of a card edit. A view-mode tag
/// sheet commits on confirmation; an edit-mode sheet only changes this draft
/// until the editor's save button is pressed.
@MainActor
final class AssetDraftController: ObservableObject {
    @Published private(set) var draft: AssetDraft
    @Published private(set) var availableTags: [Tag]
    @Published private(set) var operationError: Error?
    @Published private(set) var isMutationInFlight = false

    private let repository: any ReadingAssetRepository
    private var isEditing: Bool
    private let onSuccessfulSave: () -> Void
    private let onSuccessfulDelete: (UUID) -> Void
    private let onSuccessfulTagUpdate: () -> Void
    private var originalDraft: AssetDraft
    private var tagNamesBeingCreated: Set<String> = []

    init(
        draft: AssetDraft,
        repository: any ReadingAssetRepository,
        isEditing: Bool,
        onSuccessfulSave: @escaping () -> Void = {},
        onSuccessfulDelete: @escaping (UUID) -> Void = { _ in },
        onSuccessfulTagUpdate: @escaping () -> Void = {}
    ) {
        self.draft = draft
        originalDraft = draft
        self.repository = repository
        self.isEditing = isEditing
        self.onSuccessfulSave = onSuccessfulSave
        self.onSuccessfulDelete = onSuccessfulDelete
        self.onSuccessfulTagUpdate = onSuccessfulTagUpdate
        availableTags = draft.asset?.tags ?? []
    }

    var hasUnsavedChanges: Bool { draft != originalDraft }

    /// Dismissal follows the editable note field. Merely entering edit mode,
    /// changing tags, or typing then clearing the field must not create a
    /// discard warning. This applies equally to standalone-note drafts.
    var dismissalDecision: AssetDraftDismissalDecision {
        let currentNote = normalizedNoteContent(draft.noteContent)
        guard !currentNote.isEmpty else { return .close }
        return currentNote == normalizedNoteContent(originalDraft.noteContent)
            ? .close
            : .confirmDiscard
    }

    func loadAvailableTags(ensuring demoTagNames: [String] = []) async {
        do {
            try await fetchAvailableTags()
            try await ensureTags(named: demoTagNames)
            operationError = nil
        } catch {
            operationError = error
        }
    }

    func toggle(tag: Tag) {
        guard !tag.isSystem else { return }
        var selectedTagIDs = draft.selectedTagIDs
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
        replaceSelectedTags(selectedTagIDs)
    }

    func replaceSelectedTags(_ selectedTagIDs: Set<UUID>) {
        let lockedIDs = Set(availableTags.filter(\.isSystem).map(\.id))
        draft = draft.with(selectedTagIDs: selectedTagIDs.union(lockedIDs))
    }

    func setNoteContent(_ noteContent: String) {
        draft = draft.with(noteContent: noteContent)
    }

    func setEditing(_ isEditing: Bool) {
        self.isEditing = isEditing
    }

    @discardableResult
    func addNewTag(name: String) async throws -> Tag {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tagNamesBeingCreated.insert(normalizedName).inserted else {
            throw AssetDraftControllerError.operationInProgress
        }
        do {
            try beginMutation()
        } catch {
            tagNamesBeingCreated.remove(normalizedName)
            throw error
        }
        defer {
            tagNamesBeingCreated.remove(normalizedName)
            isMutationInFlight = false
        }
        do {
            let tag = try await repository.createTag(name: normalizedName)
            availableTags.append(tag)
            var selectedTagIDs = draft.selectedTagIDs
            selectedTagIDs.insert(tag.id)
            replaceSelectedTags(selectedTagIDs)
            operationError = nil
            return tag
        } catch {
            operationError = error
            throw error
        }
    }

    /// View-mode confirmation writes tags immediately. Edit-mode confirmation
    /// is intentionally a no-op: the card retains its local draft until save.
    func confirmTags() async throws {
        guard !isEditing else { return }
        guard let assetID = draft.assetID else { throw AssetDraftControllerError.missingAssetID }
        try beginMutation()
        defer { isMutationInFlight = false }
        do {
            try await repository.setAssetTags(assetID: assetID, tagIDs: orderedTagIDs)
            originalDraft = draft
            operationError = nil
            onSuccessfulTagUpdate()
        } catch {
            operationError = error
            throw error
        }
    }

    func save() async throws {
        try beginMutation()
        defer { isMutationInFlight = false }
        do {
            let noteContent = normalizedNoteContent(draft.noteContent)
            // Confirming an untouched standalone-note card is the same as
            // dismissing it: no asset is created and the card closes normally.
            if draft.asset == nil, draft.anchor == nil, noteContent.isEmpty {
                originalDraft = draft
                operationError = nil
                onSuccessfulSave()
                return
            }
            if let assetID = draft.assetID {
                let saved = try await repository.saveReadingAsset(
                    id: assetID,
                    noteContent: draft.noteContent,
                    tagIDs: orderedTagIDs
                )
                replaceWithSavedAsset(saved)
            } else if let anchor = draft.anchor {
                let highlighted = try await repository.createHighlight(
                    articleID: anchor.articleID,
                    anchor: anchor,
                    checksum: anchor.contentChecksum
                )
                // The highlight RPC has already succeeded. Keep its identity
                // before the second RPC so a retry only resumes saving.
                draft = AssetDraft(
                    asset: highlighted,
                    noteContent: noteContent.isEmpty ? nil : noteContent,
                    selectedTagIDs: draft.selectedTagIDs.union(highlighted.tags.filter(\.isSystem).map(\.id))
                )
                let saved = try await repository.saveReadingAsset(
                    id: highlighted.id,
                    noteContent: noteContent.isEmpty ? nil : noteContent,
                    tagIDs: orderedTagIDs
                )
                replaceWithSavedAsset(saved)
            } else {
                let saved = try await repository.createStandaloneNoteWithTags(
                    articleID: draft.articleID,
                    noteContent: noteContent,
                    tagIDs: orderedTagIDs
                )
                replaceWithSavedAsset(saved)
            }
            originalDraft = draft
            operationError = nil
            onSuccessfulSave()
        } catch {
            operationError = error
            throw error
        }
    }

    func discard() {
        draft = originalDraft
        operationError = nil
    }

    func delete() async throws {
        guard let assetID = draft.assetID else { throw AssetDraftControllerError.missingAssetID }
        try beginMutation()
        defer { isMutationInFlight = false }
        do {
            try await repository.deleteReadingAsset(id: assetID)
            operationError = nil
            onSuccessfulDelete(assetID)
        } catch {
            operationError = error
            throw error
        }
    }

    private func beginMutation() throws {
        guard !isMutationInFlight else { throw AssetDraftControllerError.operationInProgress }
        isMutationInFlight = true
    }

    private func fetchAvailableTags() async throws {
        let tags = try await repository.readTags()
        // The system's guaranteed location is a fixed first row. Preserve the
        // repository order for all ordinary user tags.
        availableTags = tags.filter(\.isSystem) + tags.filter { !$0.isSystem }
        // New assets enter the system's guaranteed location by default. This
        // baseline does not count as an edit that needs discard confirmation.
        if draft.asset == nil {
            let systemTagIDs = Set(tags.filter(\.isSystem).map(\.id))
            replaceSelectedTags(draft.selectedTagIDs.union(systemTagIDs))
            originalDraft = originalDraft.with(selectedTagIDs: originalDraft.selectedTagIDs.union(systemTagIDs))
        }
    }

    /// Debug prototypes can request a small, owner-scoped tag set without
    /// touching shared seed data. This is idempotent: a retry or a second card
    /// only reuses tags that already exist for the current user.
    private func ensureTags(named requestedNames: [String]) async throws {
        for name in requestedNames {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty,
                  !availableTags.contains(where: { $0.name == normalizedName }) else {
                continue
            }

            do {
                _ = try await repository.createTag(name: normalizedName)
            } catch {
                // Another card can finish the same create first. Reload once
                // and only surface the error if that did not produce the tag.
                let refreshedTags = try await repository.readTags()
                guard refreshedTags.contains(where: { $0.name == normalizedName }) else {
                    throw error
                }
            }
            try await fetchAvailableTags()
        }
    }

    private func replaceWithSavedAsset(_ saved: ReadingAsset) {
        draft = AssetDraft(
            asset: saved,
            noteContent: saved.noteContent,
            selectedTagIDs: Set(orderedTagIDs)
        )
    }

    private var orderedTagIDs: [UUID] {
        availableTags.compactMap { draft.selectedTagIDs.contains($0.id) ? $0.id : nil }
            + draft.selectedTagIDs.subtracting(Set(availableTags.map(\.id))).sorted { $0.uuidString < $1.uuidString }
    }

    private func normalizedNoteContent(_ content: String?) -> String {
        content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private extension AssetDraft {
    func with(selectedTagIDs: Set<UUID>) -> AssetDraft {
        if let asset {
            return AssetDraft(asset: asset, noteContent: noteContent, selectedTagIDs: selectedTagIDs)
        }
        return AssetDraft(
            anchor: anchor,
            articleID: articleID,
            noteContent: noteContent,
            selectedTagIDs: selectedTagIDs
        )
    }
}
