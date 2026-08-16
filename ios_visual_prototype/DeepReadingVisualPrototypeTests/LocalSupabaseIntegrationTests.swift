import Security
import Supabase
import XCTest
@testable import DeepReadingVisualPrototype

final class LocalSupabaseIntegrationTests: XCTestCase {
    func testDefaultSDKClientInstallsAnonymousSessionForAuthorizedRequests() async throws {
        guard let configuration = try? SupabaseRuntimeConfiguration.load() else {
            throw XCTSkip("Local Supabase runtime configuration is not present.")
        }
        let client = SupabaseClientFactory.makeClient(configuration: configuration)

        let signedIn = try await client.auth.signInAnonymously()
        XCTAssertTrue(signedIn.user.isAnonymous)
        XCTAssertNotNil(client.auth.currentSession)

        let restored = try await client.auth.session
        XCTAssertTrue(restored.user.isAnonymous)
    }

    func testSDKDefaultKeychainStorageCanRoundTripNonSecretDiagnosticValue() throws {
        let storage = KeychainLocalStorage()
        let key = "stage-c-default-storage-probe"
        try? storage.remove(key: key)
        defer { try? storage.remove(key: key) }

        try storage.store(key: key, value: Data([0x01]))
        XCTAssertEqual(try storage.retrieve(key: key), Data([0x01]))
    }

    func testDefaultKeychainCanRoundTripNonSecretDiagnosticValue() throws {
        let service = "com.deepreading.visualprototype.stage-c-diagnostic"
        let account = "default-keychain-probe"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        defer { SecItemDelete(query as CFDictionary) }

        var addQuery = query
        addQuery[kSecValueData as String] = Data([0x01])
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        XCTAssertEqual(SecItemAdd(addQuery as CFDictionary, nil), errSecSuccess)

        var readQuery = query
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(readQuery as CFDictionary, &result), errSecSuccess)
        XCTAssertEqual(result as? Data, Data([0x01]))
    }

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
