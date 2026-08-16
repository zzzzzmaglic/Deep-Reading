import XCTest
@testable import DeepReadingVisualPrototype

final class LocalSupabaseIntegrationTests: XCTestCase {
    func testAnonymousBootstrapReadsSeedArticleFromLocalService() async throws {
        guard let configuration = try? SupabaseRuntimeConfiguration.load() else {
            throw XCTSkip("Local Supabase runtime configuration is not present.")
        }
        let client = SupabaseClientFactory.makeClient(configuration: configuration)

        try await AppSessionStore(client: client).bootstrap()

        XCTAssertTrue(client.auth.currentSession?.user.isAnonymous == true)

        let article = try await SupabaseArticleRepository(client: client).readArticle(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        )
        XCTAssertFalse(article.title.isEmpty)
        XCTAssertFalse(article.blocks.isEmpty)
    }
}
