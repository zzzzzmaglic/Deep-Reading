import Foundation

struct TextAnchor: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let assetID: UUID
    let articleID: UUID
    let startBlockID: UUID
    let endBlockID: UUID
    let startUTF16Offset: Int
    let endUTF16Offset: Int
    let selectedText: String
    let contentChecksum: String

    enum CodingKeys: String, CodingKey {
        case id
        case assetID = "asset_id"
        case articleID = "article_id"
        case startBlockID = "start_block_id"
        case endBlockID = "end_block_id"
        case startUTF16Offset = "start_utf16_offset"
        case endUTF16Offset = "end_utf16_offset"
        case selectedText = "selected_text"
        case contentChecksum = "content_checksum"
    }
}

enum ReadingAssetKind: Sendable, Equatable {
    case highlight
    case linkedNote
    case standaloneNote
}

struct Tag: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let ownerID: UUID
    let name: String
    let isSystem: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
        case isSystem = "is_system"
    }
}

struct ReadingAsset: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let ownerID: UUID?
    let articleID: UUID?
    let anchor: TextAnchor?
    let noteContent: String?
    let tags: [Tag]
    let createdAt: Date?

    init(
        id: UUID = UUID(),
        ownerID: UUID? = nil,
        articleID: UUID? = nil,
        anchor: TextAnchor?,
        noteContent: String?,
        tags: [Tag] = [],
        createdAt: Date? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.articleID = articleID
        self.anchor = anchor
        self.noteContent = noteContent
        self.tags = tags
        self.createdAt = createdAt
    }

    var associatedArticleID: UUID? { articleID ?? anchor?.articleID }

    var kind: ReadingAssetKind {
        if anchor != nil {
            return noteContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? .linkedNote
                : .highlight
        }
        return .standaloneNote
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case articleID = "article_id"
        case anchor
        case noteContent = "note_content"
        case tags
        case createdAt = "created_at"
    }
}

struct AssetDraft: Sendable, Equatable {
    let asset: ReadingAsset?
    let anchor: TextAnchor?
    let articleID: UUID?
    let noteContent: String?
    let selectedTagIDs: Set<UUID>

    init(asset: ReadingAsset, noteContent: String?, selectedTagIDs: Set<UUID>) {
        self.asset = asset
        anchor = asset.anchor
        articleID = asset.associatedArticleID
        self.noteContent = noteContent
        self.selectedTagIDs = selectedTagIDs
    }

    init(anchor: TextAnchor?, articleID: UUID?, noteContent: String? = nil, selectedTagIDs: Set<UUID> = []) {
        asset = nil
        self.anchor = anchor
        self.articleID = articleID ?? anchor?.articleID
        self.noteContent = noteContent
        self.selectedTagIDs = selectedTagIDs
    }

    var assetID: UUID? { asset?.id }

    var kind: ReadingAssetKind {
        ReadingAsset(anchor: anchor, noteContent: noteContent).kind
    }

    func with(noteContent: String?) -> AssetDraft {
        AssetDraft(
            anchor: anchor,
            articleID: articleID,
            noteContent: noteContent,
            selectedTagIDs: selectedTagIDs
        ).preserving(asset: asset)
    }

    private func preserving(asset: ReadingAsset?) -> AssetDraft {
        guard let asset else { return self }
        return AssetDraft(asset: asset, noteContent: noteContent, selectedTagIDs: selectedTagIDs)
    }
}
