import Supabase
import XCTest
@testable import DeepReadingVisualPrototype

final class LocalSupabaseIntegrationTests: XCTestCase {
    func testAnonymousBootstrapReadsSeedArticleFromLocalService() async throws {
        guard let configuration = try? SupabaseRuntimeConfiguration.load() else {
            throw XCTSkip("Local Supabase runtime configuration is not present.")
        }
        let client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.anonKey,
            options: .init(auth: .init(storage: InMemoryAuthStorage()))
        )

        try await AppSessionStore(client: client).bootstrap()

        XCTAssertTrue(client.auth.currentSession?.user.isAnonymous == true)
        let article = try await SupabaseArticleRepository(client: client).readArticle(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        )
        XCTAssertFalse(article.title.isEmpty)
        XCTAssertFalse(article.blocks.isEmpty)
    }
}

private final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = nil
    }
}
