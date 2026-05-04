//
//  SupabaseAuthService.swift
//  CookSavvy
//

import Combine
import Foundation
import os
import Supabase

/// Production Supabase-backed authentication service.
///
/// Manages two auth flows:
/// 1. **Anonymous sign-in** — on first launch (or after sign-out), `startSessionIfNeeded()` automatically
///    creates an anonymous Supabase user so the app can reach premium API endpoints without requiring
///    the user to create an account.
/// 2. **Sign in with Apple** — `signInWithApple(identityToken:nonce:)` calls Supabase's OpenID Connect
///    endpoint with Apple's JWT identity token, which *links* the existing anonymous Supabase identity
///    to the Apple ID rather than creating a new user. This upgrades the account from anonymous to
///    named while preserving all user data associated with the original anonymous session.
///
/// State is published via a `CurrentValueSubject` (a thread-safe class) so callers can read auth
/// state synchronously from any context without requiring actor hops or MainActor serialization.
final class SupabaseAuthService: AuthServiceProtocol {
    private let clientProvider: SupabaseClientProviderProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    /// Lock protecting concurrent access to the session-start guard flag.
    private let _isStartingSession = OSAllocatedUnfairLock(initialState: false)

    /// Thread-safe backing subject for auth state. Readable synchronously from any context.
    let stateSubject = CurrentValueSubject<AuthState, Never>(.unknown)

    /// The current auth state, readable synchronously from any context.
    var authState: AuthState { stateSubject.value }

    /// Publisher that emits whenever auth state changes.
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    /// The Supabase user ID for the active session, or `nil` when not signed in.
    var currentUserId: String? {
        switch stateSubject.value {
        case .signedIn(let userId): return userId
        case .unknown, .signedOut: return nil
        }
    }

    /// Always `true` for the production implementation.
    var isAuthAvailable: Bool { true }

    /// `true` when the current Supabase session belongs to an anonymous user (no Apple identity linked).
    var isAnonymous: Bool {
        guard let session = clientProvider.client.auth.currentSession else {
            return false
        }
        return session.user.isAnonymous
    }

    /// Creates the service and immediately syncs state from any in-memory Supabase session.
    init(
        clientProvider: SupabaseClientProviderProtocol,
        analyticsService: AnalyticsServiceProtocol,
        logger: any LoggerProtocol
    ) {
        self.clientProvider = clientProvider
        self.analyticsService = analyticsService
        self.logger = logger
        syncStateFromCurrentSession()
    }

    /// Returns a valid JWT access token, refreshing the Supabase session if it has expired.
    /// - Throws: `AuthError.notAuthenticated` if no session exists, `AuthError.sessionUnavailable` for transient failures.
    func accessToken() async throws -> String {
        do {
            let session = try await validSession()
            updateAuthState(for: session)
            return session.accessToken
        } catch {
            handleSessionResolutionFailure(error)
            throw mapSessionResolutionError(error)
        }
    }

    /// Ensures an active Supabase session exists, creating an anonymous one if needed.
    ///
    /// Guards against concurrent calls via an unfair lock. Tries to restore an existing session
    /// first; falls back to anonymous sign-in only when explicitly signed out or when no in-memory
    /// session is present. Safe to call on every app foreground activation.
    func startSessionIfNeeded() async {
        // Atomically check-and-set the guard flag; return early if another call is in progress.
        guard _isStartingSession.withLock({ isStarting in
            guard !isStarting else { return false }
            isStarting = true
            return true
        }) else { return }
        defer { _isStartingSession.withLock { $0 = false } }

        await restoreSession()

        switch stateSubject.value {
        case .signedOut:
            do {
                try await signInAnonymously()
            } catch {
                logger.warning("Anonymous sign-in failed, will retry on next activation: \(error)")
            }
        case .unknown where clientProvider.client.auth.currentSession == nil:
            do {
                try await signInAnonymously()
            } catch {
                logger.warning("Anonymous sign-in failed (unknown state), will retry on next activation: \(error)")
            }
        default:
            break
        }
    }

    /// Creates a new anonymous Supabase session and updates published state.
    /// - Throws: `AuthError.signInFailed` on failure.
    func signInAnonymously() async throws {
        do {
            _ = try await clientProvider.client.auth.signInAnonymously()
            try await refreshSessionState()
            analyticsService.track(.anonymousAuthCompleted)
        } catch {
            logger.error("Anonymous sign-in failed: \(error)")
            throw AuthError.signInFailed
        }
    }

    /// Links the current (typically anonymous) Supabase session to an Apple identity.
    ///
    /// Supabase's `signInWithIdToken` with an existing anonymous session performs an *identity link*
    /// rather than creating a new user, preserving the anonymous user's data. The `nonce` must be
    /// the plaintext string whose SHA256 hash was sent in the original Apple authorization request
    /// (see `AppleSignInManager.signIn()`).
    /// - Parameters:
    ///   - identityToken: The JWT identity token from Apple's authorization response (`ASAuthorizationAppleIDCredential.identityToken`).
    ///   - nonce: The plaintext nonce used when creating the authorization request.
    /// - Throws: `AuthError.signInFailed` if the token is invalid, malformed, or the link fails.
    func signInWithApple(identityToken: Data, nonce: String) async throws {
        guard let token = String(data: identityToken, encoding: .utf8), !token.isEmpty else {
            throw AuthError.signInFailed
        }

        do {
            _ = try await clientProvider.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: token,
                    nonce: nonce
                )
            )
            try await refreshSessionState()
        } catch {
            logger.error("Apple sign-in failed: \(error)")
            throw AuthError.signInFailed
        }
    }

    /// Signs out the current session and publishes `.signedOut`.
    /// - Throws: `AuthError.signOutFailed` on failure.
    func signOut() async throws {
        do {
            try await clientProvider.client.auth.signOut()
            stateSubject.send(.signedOut)
        } catch {
            logger.error("Sign-out failed: \(error)")
            throw AuthError.signOutFailed
        }
    }

    /// Attempts to rehydrate an existing Supabase session from persistent storage.
    /// Updates state to `.signedIn` on success, or calls `handleSessionResolutionFailure(_:)` on error.
    func restoreSession() async {
        do {
            let session = try await validSession()
            updateAuthState(for: session)
        } catch {
            handleSessionResolutionFailure(error)
        }
    }

    /// Fetches the current valid session and updates published state.
    private func refreshSessionState() async throws {
        let session = try await validSession()
        updateAuthState(for: session)
    }

    /// Synchronously seeds initial auth state from whatever Supabase has cached in memory at init time.
    /// Publishes `.signedOut` when no session is cached, `.unknown` when the cached session is expired
    /// (a network refresh will be needed), or `.signedIn` for a valid cached session.
    private func syncStateFromCurrentSession() {
        guard let session = clientProvider.client.auth.currentSession else {
            stateSubject.send(.signedOut)
            return
        }

        guard !session.isExpired else {
            stateSubject.send(.unknown)
            return
        }

        updateAuthState(for: session)
    }

    /// Fetches a valid Supabase session, transparently refreshing the token if it has expired.
    private func validSession() async throws -> Session {
        try await clientProvider.client.auth.session
    }

    /// Determines the appropriate auth state to publish after a session resolution failure.
    ///
    /// Uses three-way logic to avoid incorrectly clearing a known-good session on transient errors:
    /// - **Explicit auth failure** (invalid/expired JWT, missing refresh token): publishes `.signedOut`.
    /// - **Already signed in**: no state change — the existing session may still be usable.
    /// - **All other failures** (network errors, etc.): publishes `.unknown` so the app can retry.
    private func handleSessionResolutionFailure(_ error: Error) {
        if isExplicitAuthFailure(error) {
            stateSubject.send(.signedOut)
        } else if case .signedIn = stateSubject.value {
            return
        } else {
            stateSubject.send(.unknown)
        }
    }

    /// Maps a session resolution error to the appropriate `AuthError` for callers.
    private func mapSessionResolutionError(_ error: Error) -> AuthError {
        isExplicitAuthFailure(error) ? .notAuthenticated : .sessionUnavailable
    }

    /// Returns `true` for Supabase errors that definitively indicate the session is gone and
    /// the user must re-authenticate (e.g., expired JWT, reused refresh token, missing session).
    /// Returns `false` for transient failures like network errors, which should not force sign-out.
    private func isExplicitAuthFailure(_ error: Error) -> Bool {
        guard let authError = error as? Supabase.AuthError else {
            return false
        }

        switch authError {
        case .sessionMissing:
            return true
        case .api(_, let errorCode, _, _):
            return [
                .sessionNotFound,
                .sessionExpired,
                .refreshTokenNotFound,
                .refreshTokenAlreadyUsed,
                .badJWT,
                .invalidJWT
            ].contains(errorCode)
        default:
            return false
        }
    }

    /// Publishes `.signedIn` with the user ID extracted from the given session.
    private func updateAuthState(for session: Session) {
        stateSubject.send(.signedIn(userId: session.user.id.uuidString))
    }
}
