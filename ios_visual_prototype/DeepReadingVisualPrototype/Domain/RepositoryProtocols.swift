import Foundation

enum ReaderOrigin: String, Sendable, Equatable, Hashable, Codable {
    case feed
    case knowledge
}

struct ReaderRoute: Sendable, Equatable, Hashable {
    let articleID: UUID
    let anchorID: UUID?
    let origin: ReaderOrigin
}

protocol ArticleRepository: Sendable {
    func readArticle(id: UUID) async throws -> Article
    func readProgress(articleID: UUID) async throws -> ReaderPosition?
}

protocol ReadingAssetRepository: Sendable {
    func readAssets(articleID: UUID?) async throws -> [ReadingAsset]
    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset
    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset
    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset
    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws
    func deleteReadingAsset(id: UUID) async throws
    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws
    func readTags() async throws -> [Tag]
    func createTag(name: String) async throws -> Tag
    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset
    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset
    func removeAssetsFromTag(tagID: UUID, assetIDs: [UUID]) async throws
    func deleteReadingAssets(ids: [UUID]) async throws
}

protocol KnowledgeBaseRepository: Sendable {
    func readHome() async throws -> KnowledgeHomeSnapshot
    func readCollection(id: UUID) async throws -> KnowledgeCollection
    func readCollectionArticles(collectionID: UUID) async throws -> [KnowledgeArticlePreview]
    func readArticleTitles(ids: Set<UUID>) async throws -> [UUID: String]
    func removeArticlesFromCollection(collectionID: UUID, articleIDs: [UUID]) async throws
}

extension ReadingAssetRepository {
    func removeAssetsFromTag(tagID: UUID, assetIDs: [UUID]) async throws {
        throw CancellationError()
    }

    func deleteReadingAssets(ids: [UUID]) async throws {
        throw CancellationError()
    }
}

protocol SessionAuthenticating: Sendable {
    func ensureSession() async throws
}
