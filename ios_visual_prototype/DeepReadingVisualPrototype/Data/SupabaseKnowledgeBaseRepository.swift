import Foundation
import Supabase

protocol SupabaseKnowledgeBaseRemote: AnyObject {
    func rpc(name: String, parameters: [String: Any]) async throws
    func readCurrentOwnerID() async throws -> UUID
    func readRows(from table: String) async throws -> [[String: Any]]
}

enum SupabaseKnowledgeBaseRepositoryError: Error {
    case invalidRow(table: String, column: String)
    case unsupportedRPCParameter(String)
    case unreadableCollection(UUID)
}

final class SupabaseKnowledgeBaseRepository: KnowledgeBaseRepository, @unchecked Sendable {
    private let client: SupabaseClient?
    private let remote: SupabaseKnowledgeBaseRemote

    init(client: SupabaseClient) {
        self.client = client
        remote = LiveSupabaseKnowledgeBaseRemote(client: client)
    }

    init(remote: SupabaseKnowledgeBaseRemote) {
        client = nil
        self.remote = remote
    }

    var clientIdentity: ObjectIdentifier? {
        client.map(ObjectIdentifier.init)
    }

    func readHome() async throws -> KnowledgeHomeSnapshot {
        async let collectionRows = remote.readRows(from: "collections")
        async let membershipRows = remote.readRows(from: "article_collections")
        async let exclusionRows = remote.readRows(from: "collection_article_exclusions")
        async let tagRows = remote.readRows(from: "tags")
        async let currentOwnerID = remote.readCurrentOwnerID()

        let collections = try collections(
            from: try await collectionRows,
            memberships: try await membershipRows,
            exclusions: try await exclusionRows,
            ownerID: try await currentOwnerID
        )
        let tags = try (try await tagRows).map(tag(from:)).sorted { lhs, rhs in
            if lhs.isSystem != rhs.isSystem { return lhs.isSystem }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return KnowledgeHomeSnapshot(collections: collections, tags: tags)
    }

    func readCollection(id: UUID) async throws -> KnowledgeCollection {
        async let collectionRows = remote.readRows(from: "collections")
        async let membershipRows = remote.readRows(from: "article_collections")
        async let exclusionRows = remote.readRows(from: "collection_article_exclusions")
        async let currentOwnerID = remote.readCurrentOwnerID()
        let collections = try collections(
            from: try await collectionRows,
            memberships: try await membershipRows,
            exclusions: try await exclusionRows,
            ownerID: try await currentOwnerID
        )
        guard let collection = collections.first(where: { $0.id == id }) else {
            throw SupabaseKnowledgeBaseRepositoryError.unreadableCollection(id)
        }
        return collection
    }

    func readCollectionArticles(collectionID: UUID) async throws -> [KnowledgeArticlePreview] {
        async let membershipRows = remote.readRows(from: "article_collections")
        async let exclusionRows = remote.readRows(from: "collection_article_exclusions")
        async let articleRows = remote.readRows(from: "articles")
        async let assetRows = remote.readRows(from: "reading_assets")
        async let currentOwnerID = remote.readCurrentOwnerID()

        let memberships = try (try await membershipRows).compactMap { row -> (articleID: UUID, position: Int)? in
            guard try requiredUUID(in: row, column: "collection_id", table: "article_collections") == collectionID else { return nil }
            return (
                try requiredUUID(in: row, column: "article_id", table: "article_collections"),
                try requiredInt(in: row, column: "position", table: "article_collections")
            )
        }.sorted { $0.position < $1.position }
        let ownerID = try await currentOwnerID
        let hiddenIDs = try Set((try await exclusionRows).compactMap { row -> UUID? in
            guard try requiredUUID(in: row, column: "owner_id", table: "collection_article_exclusions") == ownerID,
                  try requiredUUID(in: row, column: "collection_id", table: "collection_article_exclusions") == collectionID
            else { return nil }
            return try requiredUUID(in: row, column: "article_id", table: "collection_article_exclusions")
        })
        let articlesByID = try Dictionary(uniqueKeysWithValues: (try await articleRows).map { row in
            let article = try previewData(from: row)
            return (article.id, article)
        })
        let assetCounts = try (try await assetRows).reduce(into: [UUID: Int]()) { counts, row in
            guard let articleID = optionalUUID(in: row, column: "article_id") else { return }
            counts[articleID, default: 0] += 1
        }

        return memberships.compactMap { membership in
            guard !hiddenIDs.contains(membership.articleID), let article = articlesByID[membership.articleID] else { return nil }
            return KnowledgeArticlePreview(
                id: article.id,
                title: article.title,
                sourceName: article.sourceName,
                coverAssetName: article.coverAssetName,
                cognitiveDimension: article.cognitiveDimension,
                publishedAt: article.publishedAt,
                readingAssetCount: assetCounts[article.id, default: 0]
            )
        }
    }

    func readArticleTitles(ids: Set<UUID>) async throws -> [UUID: String] {
        let rows = try await remote.readRows(from: "articles")
        return try rows.reduce(into: [UUID: String]()) { titles, row in
            let id = try requiredUUID(in: row, column: "id", table: "articles")
            if ids.contains(id) {
                titles[id] = try requiredString(in: row, column: "title", table: "articles")
            }
        }
    }

    func removeArticlesFromCollection(collectionID: UUID, articleIDs: [UUID]) async throws {
        try await remote.rpc(
            name: "remove_articles_from_collection",
            parameters: [
                "p_collection_id": collectionID.uuidString,
                "p_article_ids": articleIDs.map(\.uuidString),
            ]
        )
    }

    private func collections(
        from collectionRows: [[String: Any]],
        memberships: [[String: Any]],
        exclusions: [[String: Any]],
        ownerID: UUID
    ) throws -> [KnowledgeCollection] {
        let hiddenPairs: Set<String> = try Set(exclusions.compactMap { row -> String? in
            guard try requiredUUID(in: row, column: "owner_id", table: "collection_article_exclusions") == ownerID else {
                return nil
            }
            let collectionID = try requiredUUID(in: row, column: "collection_id", table: "collection_article_exclusions")
            let articleID = try requiredUUID(in: row, column: "article_id", table: "collection_article_exclusions")
            return "\(collectionID.uuidString):\(articleID.uuidString)"
        })
        let visibleCounts = try memberships.reduce(into: [UUID: Int]()) { counts, row in
            let collectionID = try requiredUUID(in: row, column: "collection_id", table: "article_collections")
            let articleID = try requiredUUID(in: row, column: "article_id", table: "article_collections")
            if !hiddenPairs.contains("\(collectionID.uuidString):\(articleID.uuidString)") {
                counts[collectionID, default: 0] += 1
            }
        }
        return try collectionRows.map { row in
            let id = try requiredUUID(in: row, column: "id", table: "collections")
            return KnowledgeCollection(
                id: id,
                name: try requiredString(in: row, column: "name", table: "collections"),
                description: row["description"] as? String,
                isSystem: row["is_system"] as? Bool ?? false,
                visibleArticleCount: visibleCounts[id, default: 0]
            )
        }.sorted { lhs, rhs in
            if lhs.isSystem != rhs.isSystem { return lhs.isSystem }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func previewData(from row: [String: Any]) throws -> PreviewData {
        let publishedAtString = try requiredString(in: row, column: "published_at", table: "articles")
        guard let publishedAt = ISO8601DateFormatter().date(from: publishedAtString) else {
            throw SupabaseKnowledgeBaseRepositoryError.invalidRow(table: "articles", column: "published_at")
        }
        return PreviewData(
            id: try requiredUUID(in: row, column: "id", table: "articles"),
            title: try requiredString(in: row, column: "title", table: "articles"),
            sourceName: try requiredString(in: row, column: "source_name", table: "articles"),
            coverAssetName: try requiredString(in: row, column: "cover_asset_name", table: "articles"),
            cognitiveDimension: try requiredString(in: row, column: "cognitive_dimension", table: "articles"),
            publishedAt: publishedAt
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
        guard let value = optionalUUID(in: row, column: column) else {
            throw SupabaseKnowledgeBaseRepositoryError.invalidRow(table: table, column: column)
        }
        return value
    }

    private func optionalUUID(in row: [String: Any], column: String) -> UUID? {
        guard let value = row[column], !(value is NSNull) else { return nil }
        return UUID(uuidString: value as? String ?? "")
    }

    private func requiredString(in row: [String: Any], column: String, table: String) throws -> String {
        guard let value = row[column] as? String else {
            throw SupabaseKnowledgeBaseRepositoryError.invalidRow(table: table, column: column)
        }
        return value
    }

    private func requiredInt(in row: [String: Any], column: String, table: String) throws -> Int {
        guard let value = row[column] as? Int else {
            throw SupabaseKnowledgeBaseRepositoryError.invalidRow(table: table, column: column)
        }
        return value
    }

    private struct PreviewData {
        let id: UUID
        let title: String
        let sourceName: String
        let coverAssetName: String
        let cognitiveDimension: String
        let publishedAt: Date
    }
}

private final class LiveSupabaseKnowledgeBaseRemote: SupabaseKnowledgeBaseRemote, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func rpc(name: String, parameters: [String: Any]) async throws {
        let _: PostgrestResponse<Void> = try await client
            .rpc(name, params: try jsonParameters(from: parameters))
            .execute()
    }

    func readCurrentOwnerID() async throws -> UUID {
        if let session = client.auth.currentSession {
            return session.user.id
        }
        return try await client.auth.session.user.id
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
            throw SupabaseKnowledgeBaseRepositoryError.unsupportedRPCParameter(String(describing: value))
        }
    }
}
