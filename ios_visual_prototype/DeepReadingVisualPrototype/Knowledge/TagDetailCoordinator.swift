import Combine
import Foundation

enum TagSelectionAction: Equatable {
    case removeAssociation
    case deleteAssets
}

@MainActor
final class TagDetailCoordinator: ObservableObject {
    @Published private(set) var tag: Tag?
    @Published private(set) var assets: [ReadingAsset] = []
    @Published private(set) var selectedAssetIDs: Set<UUID> = []
    @Published private(set) var presentedDraft: AssetDraft?
    @Published private(set) var isMutating = false

    private let repository: any ReadingAssetRepository
    private var currentTagID: UUID?
    private var availableTags: [Tag] = []

    init(repository: any ReadingAssetRepository) {
        self.repository = repository
    }

    var selectionAction: TagSelectionAction {
        tag?.isSystem == true ? .deleteAssets : .removeAssociation
    }

    func load(tagID: UUID) async {
        currentTagID = tagID
        do {
            async let loadedTags = repository.readTags()
            async let loadedAssets = repository.readAssets(articleID: nil)
            let tags = try await loadedTags
            let allAssets = try await loadedAssets
            guard currentTagID == tagID else { return }
            availableTags = tags
            tag = tags.first { $0.id == tagID }
            assets = sort(allAssets.filter { asset in asset.tags.contains { $0.id == tagID } })
            selectedAssetIDs.removeAll()
        } catch {
            guard currentTagID == tagID else { return }
            tag = nil
            assets = []
            selectedAssetIDs.removeAll()
        }
    }

    func toggleSelection(_ assetID: UUID) {
        guard !isMutating, assets.contains(where: { $0.id == assetID }) else { return }
        if selectedAssetIDs.contains(assetID) { selectedAssetIDs.remove(assetID) } else { selectedAssetIDs.insert(assetID) }
    }

    func presentAsset(_ asset: ReadingAsset) {
        guard selectedAssetIDs.isEmpty else { return }
        presentedDraft = AssetDraft(asset: asset, noteContent: asset.noteContent, selectedTagIDs: Set(asset.tags.map(\.id)))
    }

    func dismissPresentedDraft() {
        presentedDraft = nil
    }

    func beginStandaloneNote() {
        guard let tag else { return }
        let selected = tag.isSystem
            ? Set([tag.id])
            : Set(availableTags.filter(\.isSystem).map(\.id) + [tag.id])
        presentedDraft = AssetDraft(anchor: nil, articleID: nil, noteContent: nil, selectedTagIDs: selected)
    }

    func routeToSource(for asset: ReadingAsset) -> ReaderRoute? {
        guard let anchor = asset.anchor else { return nil }
        return ReaderRoute(articleID: anchor.articleID, anchorID: anchor.id, origin: .knowledge)
    }

    @discardableResult
    func applySelectionAction() async -> Bool {
        guard !isMutating, let tag, !selectedAssetIDs.isEmpty else { return false }
        let assetIDs = assets.map(\.id).filter(selectedAssetIDs.contains)
        guard !assetIDs.isEmpty else { return false }

        isMutating = true
        defer { isMutating = false }
        do {
            switch selectionAction {
            case .removeAssociation:
                try await repository.removeAssetsFromTag(tagID: tag.id, assetIDs: assetIDs)
            case .deleteAssets:
                try await repository.deleteReadingAssets(ids: assetIDs)
            }
            await reloadCurrentTag(preserveSelection: false)
            return true
        } catch {
            return false
        }
    }

    func refreshAfterAssetMutation() async {
        presentedDraft = nil
        await reloadCurrentTag(preserveSelection: true)
    }

    private func reloadCurrentTag(preserveSelection: Bool) async {
        guard let currentTagID else { return }
        do {
            let allAssets = try await repository.readAssets(articleID: nil)
            guard self.currentTagID == currentTagID else { return }
            assets = sort(allAssets.filter { asset in asset.tags.contains { $0.id == currentTagID } })
            if preserveSelection { selectedAssetIDs.formIntersection(Set(assets.map(\.id))) } else { selectedAssetIDs.removeAll() }
        } catch {
            // A failed refresh deliberately retains visible context and selection.
        }
    }

    private func sort(_ assets: [ReadingAsset]) -> [ReadingAsset] {
        assets.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
}
