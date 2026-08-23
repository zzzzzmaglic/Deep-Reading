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
