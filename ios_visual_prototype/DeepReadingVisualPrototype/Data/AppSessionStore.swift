import Foundation
import Supabase

enum AppSessionStoreError: Error {
    case sessionUnavailableAfterAnonymousSignIn
}

final class AppSessionStore: SessionAuthenticating, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func bootstrap() async throws {
        if client.auth.currentSession == nil {
            _ = try await client.auth.signInAnonymously()
        }

        guard client.auth.currentSession != nil else {
            throw AppSessionStoreError.sessionUnavailableAfterAnonymousSignIn
        }
    }

    func ensureSession() async throws {
        try await bootstrap()
    }
}
