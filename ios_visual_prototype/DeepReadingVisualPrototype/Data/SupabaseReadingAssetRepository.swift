import Foundation
import Supabase

protocol SupabaseReadingAssetRemote: AnyObject {
    func rpcReturningUUID(name: String, parameters: [String: Any]) async throws -> UUID
    func rpc(name: String, parameters: [String: Any]) async throws
    func readRows(from table: String) async throws -> [[String: Any]]
}

enum SupabaseReadingAssetRepositoryError: Error {
    case invalidRow(table: String, column: String)
    case unsupportedRPCParameter(String)
    case invalidRPCIdentifier(String)
    case unreadableAsset(UUID)
    case unreadableTag(UUID)
}

final class SupabaseReadingAssetRepository: ReadingAssetRepository, @unchecked Sendable {
    private let remote: SupabaseReadingAssetRemote

    init(client: SupabaseClient) {
        remote = LiveSupabaseReadingAssetRemote(client: client)
    }

    init(remote: SupabaseReadingAssetRemote) {
        self.remote = remote
    }

    func readAssets(articleID: UUID?) async throws -> [ReadingAsset] {
        let assetRows = try await remote.readRows(from: "reading_assets")
        let anchorRows = try await remote.readRows(from: "asset_anchors")
        let tagRows = try await remote.readRows(from: "tags")
        let assetTagRows = try await remote.readRows(from: "asset_tags")

        let anchorsByAssetID = try Dictionary(
            uniqueKeysWithValues: anchorRows.map { row in
                let anchor = try textAnchor(from: row)
                return (anchor.assetID, anchor)
            }
        )
        let tagsByID = try Dictionary(
            uniqueKeysWithValues: tagRows.map { row in
                let tag = try tag(from: row)
                return (tag.id, tag)
            }
        )
        var tagsByAssetID: [UUID: [Tag]] = [:]
        for row in assetTagRows {
            let assetID = try requiredUUID(in: row, column: "asset_id", table: "asset_tags")
            let tagID = try requiredUUID(in: row, column: "tag_id", table: "asset_tags")
            if let tag = tagsByID[tagID] {
                tagsByAssetID[assetID, default: []].append(tag)
            }
        }

        let assets = try assetRows.map { row in
            let assetID = try requiredUUID(in: row, column: "id", table: "reading_assets")
            return try readingAsset(
                from: row,
                anchor: anchorsByAssetID[assetID],
                tags: tagsByAssetID[assetID] ?? []
            )
        }
        guard let articleID else { return assets }
        return assets.filter { asset in
            asset.anchor?.articleID == articleID || (asset.anchor == nil && asset.articleID == articleID)
        }
    }

    func createHighlight(articleID: UUID, anchor: TextAnchor, checksum: String) async throws -> ReadingAsset {
        let assetID = try await remote.rpcReturningUUID(
            name: "create_highlight_asset",
            parameters: [
                "p_article_id": articleID.uuidString,
                "p_start_block_id": anchor.startBlockID.uuidString,
                "p_end_block_id": anchor.endBlockID.uuidString,
                "p_start_utf16_offset": anchor.startUTF16Offset,
                "p_end_utf16_offset": anchor.endUTF16Offset,
                "p_selected_text": anchor.selectedText,
                "p_content_checksum": checksum,
            ]
        )
        return try await readAsset(id: assetID)
    }

    func createStandaloneNote(articleID: UUID?, noteContent: String) async throws -> ReadingAsset {
        let assetID = try await remote.rpcReturningUUID(
            name: "create_standalone_note",
            parameters: [
                "p_note_content": noteContent,
                "p_article_id": articleID?.uuidString ?? NSNull(),
            ]
        )
        return try await readAsset(id: assetID)
    }

    func updateReadingAsset(id: UUID, noteContent: String?) async throws -> ReadingAsset {
        let assetID = try await remote.rpcReturningUUID(
            name: "update_reading_asset",
            parameters: [
                "p_asset_id": id.uuidString,
                "p_note_content": noteContent ?? NSNull(),
            ]
        )
        return try await readAsset(id: assetID)
    }

    func setAssetTags(assetID: UUID, tagIDs: [UUID]) async throws {
        try await remote.rpc(
            name: "set_asset_tags",
            parameters: [
                "p_asset_id": assetID.uuidString,
                "p_tag_ids": tagIDs.map(\.uuidString),
            ]
        )
    }

    func deleteReadingAsset(id: UUID) async throws {
        try await remote.rpc(
            name: "delete_reading_asset",
            parameters: ["p_asset_id": id.uuidString]
        )
    }

    func upsertReadingProgress(articleID: UUID, position: ReaderPosition) async throws {
        try await remote.rpc(
            name: "upsert_reading_progress",
            parameters: [
                "p_article_id": articleID.uuidString,
                "p_block_id": position.blockID?.uuidString ?? NSNull(),
                "p_utf16_offset": position.utf16Offset,
            ]
        )
    }

    func readTags() async throws -> [Tag] {
        try await remote.readRows(from: "tags").map(tag(from:))
    }

    func createTag(name: String) async throws -> Tag {
        let tagID = try await remote.rpcReturningUUID(
            name: "create_tag",
            parameters: ["p_name": name]
        )
        let tags = try await readTags()
        guard let tag = tags.first(where: { $0.id == tagID }) else {
            throw SupabaseReadingAssetRepositoryError.unreadableTag(tagID)
        }
        return tag
    }

    func saveReadingAsset(id: UUID, noteContent: String?, tagIDs: [UUID]) async throws -> ReadingAsset {
        let assetID = try await remote.rpcReturningUUID(
            name: "save_reading_asset",
            parameters: [
                "p_asset_id": id.uuidString,
                "p_note_content": noteContent ?? NSNull(),
                "p_tag_ids": tagIDs.map(\.uuidString),
            ]
        )
        return try await readAsset(id: assetID)
    }

    func createStandaloneNoteWithTags(articleID: UUID?, noteContent: String, tagIDs: [UUID]) async throws -> ReadingAsset {
        let assetID = try await remote.rpcReturningUUID(
            name: "create_standalone_note_with_tags",
            parameters: [
                "p_note_content": noteContent,
                "p_article_id": articleID?.uuidString ?? NSNull(),
                "p_tag_ids": tagIDs.map(\.uuidString),
            ]
        )
        return try await readAsset(id: assetID)
    }

    private func readAsset(id: UUID) async throws -> ReadingAsset {
        let assets = try await readAssets(articleID: nil)
        guard let asset = assets.first(where: { $0.id == id }) else {
            throw SupabaseReadingAssetRepositoryError.unreadableAsset(id)
        }
        return asset
    }

    private func readingAsset(from row: [String: Any], anchor: TextAnchor?, tags: [Tag]) throws -> ReadingAsset {
        ReadingAsset(
            id: try requiredUUID(in: row, column: "id", table: "reading_assets"),
            ownerID: optionalUUID(in: row, column: "owner_id", table: "reading_assets"),
            articleID: optionalUUID(in: row, column: "article_id", table: "reading_assets"),
            anchor: anchor,
            noteContent: optionalString(in: row, column: "note_content", table: "reading_assets"),
            tags: tags,
            createdAt: optionalDate(in: row, column: "created_at")
        )
    }

    private func textAnchor(from row: [String: Any]) throws -> TextAnchor {
        TextAnchor(
            id: try requiredUUID(in: row, column: "id", table: "asset_anchors"),
            assetID: try requiredUUID(in: row, column: "asset_id", table: "asset_anchors"),
            articleID: try requiredUUID(in: row, column: "article_id", table: "asset_anchors"),
            startBlockID: try requiredUUID(in: row, column: "start_block_id", table: "asset_anchors"),
            endBlockID: try requiredUUID(in: row, column: "end_block_id", table: "asset_anchors"),
            startUTF16Offset: try requiredInt(in: row, column: "start_utf16_offset", table: "asset_anchors"),
            endUTF16Offset: try requiredInt(in: row, column: "end_utf16_offset", table: "asset_anchors"),
            selectedText: try requiredString(in: row, column: "selected_text", table: "asset_anchors"),
            contentChecksum: try requiredString(in: row, column: "content_checksum", table: "asset_anchors")
        )
    }

    private func tag(from row: [String: Any]) throws -> Tag {
        Tag(
            id: try requiredUUID(in: row, column: "id", table: "tags"),
            ownerID: try requiredUUID(in: row, column: "owner_id", table: "tags"),
            name: try requiredString(in: row, column: "name", table: "tags"),
            isSystem: row["is_system"] as? Bool ?? false
        )
    }

    private func requiredUUID(in row: [String: Any], column: String, table: String) throws -> UUID {
        guard let value = optionalUUID(in: row, column: column, table: table) else {
            throw SupabaseReadingAssetRepositoryError.invalidRow(table: table, column: column)
        }
        return value
    }

    private func optionalUUID(in row: [String: Any], column: String, table: String) -> UUID? {
        guard let value = row[column], !(value is NSNull) else { return nil }
        return UUID(uuidString: value as? String ?? "")
    }

    private func requiredString(in row: [String: Any], column: String, table: String) throws -> String {
        guard let value = row[column] as? String else {
            throw SupabaseReadingAssetRepositoryError.invalidRow(table: table, column: column)
        }
        return value
    }

    private func optionalString(in row: [String: Any], column: String, table: String) -> String? {
        row[column] as? String
    }

    private func requiredInt(in row: [String: Any], column: String, table: String) throws -> Int {
        guard let value = row[column] as? Int else {
            throw SupabaseReadingAssetRepositoryError.invalidRow(table: table, column: column)
        }
        return value
    }

    private func optionalDate(in row: [String: Any], column: String) -> Date? {
        guard let value = row[column] as? String else { return nil }
        if let decimalIndex = value.firstIndex(of: "."),
           let timezoneIndex = value[decimalIndex...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" }) {
            let fractionalSeconds = value[value.index(after: decimalIndex)..<timezoneIndex]
            let wholeSecondsValue = String(value[..<decimalIndex]) + String(value[timezoneIndex...])
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let wholeSeconds = formatter.date(from: wholeSecondsValue),
               let fraction = Double("0.\(fractionalSeconds)") {
                return wholeSeconds.addingTimeInterval(fraction)
            }
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }
}

private final class LiveSupabaseReadingAssetRemote: SupabaseReadingAssetRemote, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func rpcReturningUUID(name: String, parameters: [String: Any]) async throws -> UUID {
        let response: PostgrestResponse<String> = try await client
            .rpc(name, params: try jsonParameters(from: parameters))
            .execute()
        guard let identifier = UUID(uuidString: response.value) else {
            throw SupabaseReadingAssetRepositoryError.invalidRPCIdentifier(response.value)
        }
        return identifier
    }

    func rpc(name: String, parameters: [String: Any]) async throws {
        let _: PostgrestResponse<Void> = try await client
            .rpc(name, params: try jsonParameters(from: parameters))
            .execute()
    }

    func readRows(from table: String) async throws -> [[String: Any]] {
        let response: PostgrestResponse<[[String: AnyJSON]]> = try await client
            .from(table)
            .select()
            .execute()
        return response.value.map { $0.mapValues(\.value) }
    }

    private func jsonParameters(from parameters: [String: Any]) throws -> JSONObject {
        try parameters.mapValues { value in
            if value is NSNull { return .null }
            if let value = value as? String { return .string(value) }
            if let value = value as? Int { return .integer(value) }
            if let value = value as? [String] { return .array(value.map(AnyJSON.string)) }
            throw SupabaseReadingAssetRepositoryError.unsupportedRPCParameter(String(describing: value))
        }
    }
}
