import Foundation
import Supabase

struct AppSession: Sendable, Equatable {
    let isAnonymous: Bool
    let expiresAt: Date

    var isUsableAnonymousSession: Bool {
        isAnonymous && expiresAt > Date()
    }
}

protocol AppSessionRemote: AnyObject {
    func currentSession() -> AppSession?
    func restoreSession() async throws -> AppSession?
    func signOut() async throws
    func signInAnonymously() async throws -> AppSession
}

enum AppSessionStoreError: Error {
    case unavailableAnonymousSession
}

final class AppSessionStore: SessionAuthenticating, @unchecked Sendable {
    private let remote: AppSessionRemote

    init(client: SupabaseClient) {
        remote = LiveAppSessionRemote(client: client)
    }

    init(remote: AppSessionRemote) {
        self.remote = remote
    }

    func bootstrap() async throws {
        if let cachedSession = remote.currentSession(), cachedSession.isUsableAnonymousSession {
            return
        }

        let hadCachedSession = remote.currentSession() != nil

        if let cachedSession = remote.currentSession(), cachedSession.isAnonymous {
            if let restoredSession = try? await remote.restoreSession(),
               restoredSession.isUsableAnonymousSession,
               remote.currentSession()?.isUsableAnonymousSession == true {
                return
            }
        }

        if hadCachedSession {
            try await remote.signOut()
        }

        let newSession = try await remote.signInAnonymously()
        guard newSession.isUsableAnonymousSession,
              let confirmedSession = try await remote.restoreSession(),
              confirmedSession.isUsableAnonymousSession else {
            throw AppSessionStoreError.unavailableAnonymousSession
        }
    }

    func ensureSession() async throws {
        try await bootstrap()
    }
}

private final class LiveAppSessionRemote: AppSessionRemote, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func currentSession() -> AppSession? {
        client.auth.currentSession.map(AppSession.init)
    }

    func restoreSession() async throws -> AppSession? {
        AppSession(session: try await client.auth.session)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func signInAnonymously() async throws -> AppSession {
        AppSession(session: try await client.auth.signInAnonymously())
    }
}

private extension AppSession {
    init(session: Session) {
        isAnonymous = session.user.isAnonymous
        expiresAt = Date(timeIntervalSince1970: session.expiresAt)
    }
}
