//
//  NoOpAuthService.swift
//  CookSavvy
//

import Combine
import Foundation

/// RELEASE fallback auth service used when Supabase keys are absent from `APIKeys.plist`.
///
/// All operations are no-ops or succeed silently, preventing crashes in production builds
/// where Supabase is not configured. `isAuthAvailable` is `false` so the rest of the app
/// can conditionally hide auth-dependent UI (e.g., Sign in with Apple button) rather than
/// showing a broken flow.
final class NoOpAuthService: AuthServiceProtocol {
    let authState: AuthState = .signedOut
    let currentUserId: String? = nil
    let isAnonymous: Bool = false
    /// Always `false` — signals to the app that authentication is unavailable in this build configuration.
    let isAuthAvailable: Bool = false

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        Just(.signedOut).eraseToAnyPublisher()
    }

    /// Always throws `AuthError.notAuthenticated` since no auth is available.
    func accessToken() async throws -> String {
        throw AuthError.notAuthenticated
    }

    /// No-op in RELEASE fallback mode because there is no remote session to bootstrap.
    func startSessionIfNeeded() async {}
    /// Always fails because anonymous sign-in is unavailable without configured auth backend.
    func signInAnonymously() async throws { throw AuthError.signInFailed }
    /// Always fails because Apple identity linking is unavailable without configured auth backend.
    func signInWithApple(identityToken: Data, nonce: String) async throws { throw AuthError.signInFailed }
    /// Signs out silently (no session to clear).
    func signOut() async throws {}
    /// No-op in fallback mode because there is no persisted auth session.
    func restoreSession() async {}
}
