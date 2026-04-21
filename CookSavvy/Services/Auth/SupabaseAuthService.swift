//
//  SupabaseAuthService.swift
//  CookSavvy
//

import Combine
import Foundation
import Supabase

actor SupabaseAuthService: AuthServiceProtocol {
    private let clientProvider: SupabaseClientProviderProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    private var isStartingSession = false

    // CurrentValueSubject is a thread-safe class; nonisolated let on an actor
    // can be read synchronously from outside without crossing the actor boundary.
    nonisolated let stateSubject = CurrentValueSubject<AuthState, Never>(.unknown)

    nonisolated var authState: AuthState { stateSubject.value }

    nonisolated var authStatePublisher: AnyPublisher<AuthState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    nonisolated var currentUserId: String? {
        switch stateSubject.value {
        case .signedIn(let userId): return userId
        case .unknown, .signedOut: return nil
        }
    }

    nonisolated var isAuthAvailable: Bool { true }

    nonisolated var isAnonymous: Bool {
        guard let session = clientProvider.client.auth.currentSession else {
            return false
        }
        return session.user.isAnonymous
    }

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

    func startSessionIfNeeded() async {
        guard !isStartingSession else { return }

        isStartingSession = true
        defer { isStartingSession = false }

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

    func signOut() async throws {
        do {
            try await clientProvider.client.auth.signOut()
            stateSubject.send(.signedOut)
        } catch {
            logger.error("Sign-out failed: \(error)")
            throw AuthError.signOutFailed
        }
    }

    func restoreSession() async {
        do {
            let session = try await validSession()
            updateAuthState(for: session)
        } catch {
            handleSessionResolutionFailure(error)
        }
    }

    private func refreshSessionState() async throws {
        let session = try await validSession()
        updateAuthState(for: session)
    }

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

    private func validSession() async throws -> Session {
        try await clientProvider.client.auth.session
    }

    private func handleSessionResolutionFailure(_ error: Error) {
        if isExplicitAuthFailure(error) {
            stateSubject.send(.signedOut)
        } else if case .signedIn = stateSubject.value {
            return
        } else {
            stateSubject.send(.unknown)
        }
    }

    private func mapSessionResolutionError(_ error: Error) -> AuthError {
        isExplicitAuthFailure(error) ? .notAuthenticated : .sessionUnavailable
    }

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

    private func updateAuthState(for session: Session) {
        stateSubject.send(.signedIn(userId: session.user.id.uuidString))
    }
}
