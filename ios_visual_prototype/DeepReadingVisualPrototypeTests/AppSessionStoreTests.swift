import XCTest
@testable import DeepReadingVisualPrototype

final class AppSessionStoreTests: XCTestCase {
    func testBootstrapKeepsExistingValidAnonymousSession() async throws {
        let remote = FakeAppSessionRemote(cachedSession: AppSession(isAnonymous: true, expiresAt: .distantFuture))
        try await AppSessionStore(remote: remote).bootstrap()
        XCTAssertEqual(remote.restoreCalls, 0)
        XCTAssertEqual(remote.signOutCalls, 0)
        XCTAssertEqual(remote.signInCalls, 0)
    }

    func testBootstrapReplacesNonAnonymousCachedSession() async throws {
        let remote = FakeAppSessionRemote(cachedSession: AppSession(isAnonymous: false, expiresAt: .distantFuture))
        try await AppSessionStore(remote: remote).bootstrap()
        XCTAssertEqual(remote.signOutCalls, 1)
        XCTAssertEqual(remote.signInCalls, 1)
    }

    func testBootstrapRestoresExpiredAnonymousSessionBeforeSigningInAgain() async throws {
        let remote = FakeAppSessionRemote(cachedSession: AppSession(isAnonymous: true, expiresAt: .distantPast))
        remote.restoredSession = AppSession(isAnonymous: true, expiresAt: .distantFuture)
        try await AppSessionStore(remote: remote).bootstrap()
        XCTAssertEqual(remote.restoreCalls, 1)
        XCTAssertEqual(remote.signOutCalls, 0)
        XCTAssertEqual(remote.signInCalls, 0)
    }

    func testBootstrapReplacesExpiredAnonymousSessionThatCannotBeRestored() async throws {
        let remote = FakeAppSessionRemote(cachedSession: AppSession(isAnonymous: true, expiresAt: .distantPast))
        remote.restoredSession = nil
        try await AppSessionStore(remote: remote).bootstrap()
        XCTAssertEqual(remote.restoreCalls, 1)
        XCTAssertEqual(remote.signOutCalls, 1)
        XCTAssertEqual(remote.signInCalls, 1)
    }

    func testBootstrapAcceptsNewAnonymousSessionWhenCurrentSessionConfirmsItAndRestoreThrows() async throws {
        let remote = FakeAppSessionRemote(cachedSession: nil)
        remote.restoreError = FakeSessionError.restoreFailed

        try await AppSessionStore(remote: remote).bootstrap()

        XCTAssertEqual(remote.signInCalls, 1)
        XCTAssertEqual(remote.restoreCalls, 0)
        XCTAssertEqual(remote.currentSession()?.isUsableAnonymousSession, true)
    }

    func testBootstrapRejectsFreshAnonymousSignInWhenSDKSessionCannotBeRestored() async {
        let remote = FakeAppSessionRemote(cachedSession: nil)
        remote.signInUpdatesCurrentSession = false
        remote.restoreError = FakeSessionError.restoreFailed

        await assertUnavailableAnonymousSession(remote)

        XCTAssertEqual(remote.signInCalls, 1)
        XCTAssertEqual(remote.restoreCalls, 1)
        XCTAssertNil(remote.currentSession())
    }

    func testBootstrapRejectsExpiredFreshSignInWhenSDKSessionIsTemporarilyUnavailable() async {
        let remote = FakeAppSessionRemote(cachedSession: nil)
        remote.signInSession = AppSession(isAnonymous: true, expiresAt: .distantPast)
        remote.signInUpdatesCurrentSession = false

        await assertUnavailableAnonymousSession(remote)
    }

    func testBootstrapRejectsNonAnonymousFreshSignInWhenSDKSessionIsTemporarilyUnavailable() async {
        let remote = FakeAppSessionRemote(cachedSession: nil)
        remote.signInSession = AppSession(isAnonymous: false, expiresAt: .distantFuture)
        remote.signInUpdatesCurrentSession = false

        await assertUnavailableAnonymousSession(remote)
    }

    func testBootstrapSurfacesAnonymousSignInFailure() async {
        let remote = FakeAppSessionRemote(cachedSession: nil)
        remote.signInError = FakeSessionError.signInFailed
        do {
            try await AppSessionStore(remote: remote).bootstrap()
            XCTFail("Expected anonymous sign-in failure to be surfaced.")
        } catch {
            XCTAssertEqual(error as? FakeSessionError, .signInFailed)
        }
    }

    private func assertUnavailableAnonymousSession(_ remote: FakeAppSessionRemote) async {
        do {
            try await AppSessionStore(remote: remote).bootstrap()
            XCTFail("Expected an unsafe anonymous session to be rejected.")
        } catch {
            XCTAssertTrue(error is AppSessionStoreError)
        }
    }
}

private enum FakeSessionError: Error, Equatable {
    case restoreFailed
    case signInFailed
}

private final class FakeAppSessionRemote: AppSessionRemote, @unchecked Sendable {
    var cachedSession: AppSession?
    var restoredSession: AppSession?
    var signInSession = AppSession(isAnonymous: true, expiresAt: .distantFuture)
    var signInError: Error?
    var restoreError: Error?
    var signInUpdatesCurrentSession = true
    private(set) var restoreCalls = 0
    private(set) var signOutCalls = 0
    private(set) var signInCalls = 0

    init(cachedSession: AppSession?) { self.cachedSession = cachedSession }
    func currentSession() -> AppSession? { cachedSession }
    func restoreSession() async throws -> AppSession? {
        restoreCalls += 1
        if let restoreError { throw restoreError }
        if let restoredSession {
            cachedSession = restoredSession
            return restoredSession
        }
        return cachedSession
    }
    func signOut() async throws { signOutCalls += 1; cachedSession = nil }
    func signInAnonymously() async throws -> AppSession {
        signInCalls += 1
        if let signInError { throw signInError }
        if signInUpdatesCurrentSession {
            cachedSession = signInSession
        }
        return signInSession
    }
}
