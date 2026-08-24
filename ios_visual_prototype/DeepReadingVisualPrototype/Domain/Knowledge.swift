import Foundation

struct KnowledgeCollection: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let isSystem: Bool
    let visibleArticleCount: Int
}

struct KnowledgeHomeSnapshot: Sendable, Equatable {
    let collections: [KnowledgeCollection]
    let tags: [Tag]
    let tagAssetCounts: [UUID: Int]

    init(
        collections: [KnowledgeCollection],
        tags: [Tag],
        tagAssetCounts: [UUID: Int] = [:]
    ) {
        self.collections = collections
        self.tags = tags
        self.tagAssetCounts = tagAssetCounts
    }
}

struct KnowledgeArticlePreview: Sendable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let sourceName: String
    let coverAssetName: String
    let cognitiveDimension: String
    let publishedAt: Date
    let readingAssetCount: Int
}
