import Foundation

struct Article: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let sourceName: String
    let contentChecksum: String
    let blocks: [ArticleBlock]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sourceName = "source_name"
        case contentChecksum = "content_checksum"
        case blocks
    }
}

enum ArticleBlockKind: String, Codable, Sendable, Equatable {
    case paragraph
    case image
}

struct ArticleBlock: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let articleID: UUID
    let position: Int
    let content: String
    let kind: ArticleBlockKind

    init(
        id: UUID,
        articleID: UUID,
        position: Int,
        content: String,
        kind: ArticleBlockKind = .paragraph
    ) {
        self.id = id
        self.articleID = articleID
        self.position = position
        self.content = content
        self.kind = kind
    }

    enum CodingKeys: String, CodingKey {
        case id
        case articleID = "article_id"
        case position
        case content
        case kind
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        articleID = try values.decode(UUID.self, forKey: .articleID)
        position = try values.decode(Int.self, forKey: .position)
        content = try values.decode(String.self, forKey: .content)
        kind = try values.decodeIfPresent(ArticleBlockKind.self, forKey: .kind) ?? .paragraph
    }
}

struct ReaderPosition: Codable, Sendable, Equatable {
    let blockID: UUID?
    let utf16Offset: Int

    init(blockID: UUID?, utf16Offset: Int) {
        self.blockID = blockID
        self.utf16Offset = utf16Offset
    }

    enum CodingKeys: String, CodingKey {
        case blockID = "block_id"
        case utf16Offset = "utf16_offset"
    }
}
