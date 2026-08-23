import Combine
import Foundation

enum SummaryNavigationDestination: Hashable {
    case summary(UUID)
}

enum ArticleAssetSummaryFailure: LocalizedError, Equatable {
    case loadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed: "标注与笔记未能加载，请重试。"
        case .deleteFailed: "删除失败，请重试。"
        }
    }
}

/// State and domain behavior for the current-article summary. Navigation is
/// ultimately owned by `AppRootView`; this small path mirror makes the
/// replacement contract explicit and keeps it unit-testable.
@MainActor
final class ArticleAssetSummaryCoordinator: ObservableObject {
    @Published private(set) var assets: [ReadingAsset] = []
    @Published private(set) var selectedAssetIDs: Set<UUID> = []
    @Published private(set) var navigationPath: [SummaryNavigationDestination]
    @Published private(set) var loadFailure: ArticleAssetSummaryFailure?
    @Published private(set) var deletionFailure: ArticleAssetSummaryFailure?
    @Published private(set) var isDeleting = false

    let articleID: UUID
    let origin: ReaderOrigin

    private let articleRepository: any ArticleRepository
    private let readingAssetRepository: any ReadingAssetRepository
    private var article: Article?
    /// Deletes are still individual RPCs, so a failed request can follow
    /// earlier successful requests. Retain that durable progress and retry
    /// only the IDs which have not reported success yet.
    private var deletionBatchAssetIDs: Set<UUID>?
    private var successfullyDeletedAssetIDs: Set<UUID> = []

    init(
        articleID: UUID,
        origin: ReaderOrigin,
        articleRepository: any ArticleRepository,
        readingAssetRepository: any ReadingAssetRepository
    ) {
        self.articleID = articleID
        self.origin = origin
        self.articleRepository = articleRepository
        self.readingAssetRepository = readingAssetRepository
        navigationPath = [.summary(articleID)]
    }

    func load() async throws {
        do {
            async let loadedArticle = articleRepository.readArticle(id: articleID)
            async let loadedAssets = readingAssetRepository.readAssets(articleID: articleID)
            article = try await loadedArticle
            assets = sort(try await loadedAssets)
            loadFailure = nil
        } catch {
            loadFailure = .loadFailed
            throw error
        }
    }

    func retryLoad() {
        Task { @MainActor [weak self] in
            try? await self?.load()
        }
    }

    func toggleSelection(_ assetID: UUID) {
        guard !isDeleting else { return }
        // A partially deleted row is deliberately kept visible until the
        // original batch completes. If the user changes selection, never let
        // that ghost ID become part of a fresh batch.
        if successfullyDeletedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
            resetDeletionBatchProgress()
            return
        }
        selectedAssetIDs.subtract(successfullyDeletedAssetIDs)
        if selectedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
        } else {
            selectedAssetIDs.insert(assetID)
        }
        resetDeletionBatchProgress()
    }

    func clearSelection() {
        guard !isDeleting else { return }
        selectedAssetIDs.removeAll()
        resetDeletionBatchProgress()
    }

    func showInArticle(_ asset: ReadingAsset) -> ReaderRoute {
        precondition(asset.anchor != nil, "Only anchored assets can return to article text")
        navigationPath.removeAll { destination in
            if case let .summary(id) = destination { return id == articleID }
            return false
        }
        return ReaderRoute(
            articleID: asset.anchor!.articleID,
            anchorID: asset.anchor!.id,
            origin: origin
        )
    }

    /// A refresh happens only after every RPC reports success. A failed batch
    /// deliberately leaves the rendered list and selection untouched so the
    /// user has a visible retry path rather than losing their context.
    func deleteSelectedAssets(_ assetIDs: [UUID]) async throws {
        guard !assetIDs.isEmpty else { return }
        guard !isDeleting else { return }
        let requestedIDs = Set(assetIDs)
        guard !requestedIDs.isEmpty else { return }
        if deletionBatchAssetIDs != requestedIDs {
            deletionBatchAssetIDs = requestedIDs
            successfullyDeletedAssetIDs.removeAll()
        }
        isDeleting = true
        defer { isDeleting = false }
        do {
            for assetID in assetIDs {
                guard !successfullyDeletedAssetIDs.contains(assetID) else { continue }
                try await readingAssetRepository.deleteReadingAsset(id: assetID)
                successfullyDeletedAssetIDs.insert(assetID)
            }
            let refreshedAssets = try await readingAssetRepository.readAssets(articleID: articleID)
            assets = sort(refreshedAssets)
            selectedAssetIDs.removeAll()
            resetDeletionBatchProgress()
        } catch {
            deletionFailure = .deleteFailed
            throw error
        }
    }

    @discardableResult
    func deleteSelection() async -> Bool {
        guard !isDeleting else { return false }
        do {
            let visibleOrder = assets.map(\.id).filter(selectedAssetIDs.contains)
            let nonVisibleSelection = selectedAssetIDs
                .subtracting(visibleOrder)
                .sorted { $0.uuidString < $1.uuidString }
            try await deleteSelectedAssets(visibleOrder + nonVisibleSelection)
            return true
        } catch {
            // `deleteSelectedAssets` keeps retryable state intact.
            return false
        }
    }

    func refreshAfterAssetMutation() async {
        do {
            let loadedAssets = try await readingAssetRepository.readAssets(articleID: articleID)
            assets = sort(loadedAssets)
            loadFailure = nil
        } catch {
            loadFailure = .loadFailed
        }
    }

    private func sort(_ source: [ReadingAsset]) -> [ReadingAsset] {
        let blockOrder = Dictionary(uniqueKeysWithValues: (article?.blocks ?? []).map { ($0.id, $0.position) })
        let anchored = source.filter { $0.anchor != nil }.sorted { lhs, rhs in
            guard let left = lhs.anchor, let right = rhs.anchor else { return false }
            let leftBlock = blockOrder[left.startBlockID] ?? .max
            let rightBlock = blockOrder[right.startBlockID] ?? .max
            if leftBlock != rightBlock { return leftBlock < rightBlock }
            if left.startUTF16Offset != right.startUTF16Offset {
                return left.startUTF16Offset < right.startUTF16Offset
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let standalone = source.filter { $0.anchor == nil }.sorted { lhs, rhs in
            let leftDate = lhs.createdAt ?? .distantPast
            let rightDate = rhs.createdAt ?? .distantPast
            if leftDate != rightDate { return leftDate > rightDate }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return anchored + standalone
    }

    private func resetDeletionBatchProgress() {
        deletionBatchAssetIDs = nil
        successfullyDeletedAssetIDs.removeAll()
        deletionFailure = nil
    }
}
