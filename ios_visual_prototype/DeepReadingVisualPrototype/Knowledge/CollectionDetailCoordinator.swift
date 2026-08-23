import Combine
import Foundation

@MainActor
final class CollectionDetailCoordinator: ObservableObject {
    @Published private(set) var collection: KnowledgeCollection?
    @Published private(set) var articles: [KnowledgeArticlePreview] = []
    @Published private(set) var selectedArticleIDs: Set<UUID> = []
    @Published private(set) var isRemoving = false

    private let repository: any KnowledgeBaseRepository

    init(repository: any KnowledgeBaseRepository) {
        self.repository = repository
    }

    func load(collectionID: UUID) async {
        do {
            async let loadedCollection = repository.readCollection(id: collectionID)
            async let loadedArticles = repository.readCollectionArticles(collectionID: collectionID)
            collection = try await loadedCollection
            articles = try await loadedArticles
            selectedArticleIDs.removeAll()
        } catch {
            collection = nil
            articles = []
            selectedArticleIDs.removeAll()
        }
    }

    func toggleSelection(articleID: UUID) {
        guard !isRemoving, !isLockedCollection, articles.contains(where: { $0.id == articleID }) else { return }
        if selectedArticleIDs.contains(articleID) {
            selectedArticleIDs.remove(articleID)
        } else {
            selectedArticleIDs.insert(articleID)
        }
    }

    @discardableResult
    func removeSelection() async -> Bool {
        guard !isRemoving, !isLockedCollection, let collection, !selectedArticleIDs.isEmpty else { return false }
        let articleIDs = articles.map(\.id).filter(selectedArticleIDs.contains)
        guard !articleIDs.isEmpty else { return false }

        isRemoving = true
        defer { isRemoving = false }
        do {
            try await repository.removeArticlesFromCollection(collectionID: collection.id, articleIDs: articleIDs)
            articles = try await repository.readCollectionArticles(collectionID: collection.id)
            selectedArticleIDs.removeAll()
            return true
        } catch {
            return false
        }
    }

    var isLockedCollection: Bool {
        collection?.isSystem == true || collection?.name == "往期推文"
    }
}
