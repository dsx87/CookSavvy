//
//  MockAuthService.swift
//  CookSavvy
//

import Foundation

#if DEBUG
/// Predictable in-memory auth service for use in DEBUG builds (when Supabase is not configured) and UI tests.
///
/// All state transitions are synchronous and driven by the caller. Exposes stub properties
/// (`stubbedAccessToken`, `signInAnonymouslyError`, etc.) so test code can inject specific
/// success and failure scenarios without needing a real Supabase connection.
/// Call counters on each method allow tests to assert how many times a method was called.
final class MockAuthService: AuthServiceProtocol {
    private let authStateBroadcaster: AsyncValueBroadcaster<AuthState>
    /// The current mock auth state, readable synchronously.
    var authState: AuthState { authStateBroadcaster.value }
    private let analyticsService: AnalyticsServiceProtocol?

    /// Number of times `signInAnonymously()` has been called.
    private(set) var signInAnonymouslyCallCount = 0
    /// Number of times `signInWithApple(identityToken:nonce:)` has been called.
    private(set) var signInWithAppleCallCount = 0
    /// Number of times `signOut()` has been called.
    private(set) var signOutCallCount = 0
    /// Number of times `deleteAccount()` has been called.
    private(set) var deleteAccountCallCount = 0
    /// Number of times `restoreSession()` has been called.
    private(set) var restoreSessionCallCount = 0
    /// Number of times `startSessionIfNeeded()` has been called.
    private(set) var startSessionIfNeededCallCount = 0

    var authStateUpdates: AsyncStream<AuthState> {
        authStateBroadcaster.updates
    }

    /// The token returned by `accessToken()`. Defaults to `"mock-supabase-token"`.
    var stubbedAccessToken: String
    /// When set, `accessToken()` throws this error instead of returning the stubbed token.
    var accessTokenError: Error?
    /// When set, `signInAnonymously()` throws this error.
    var signInAnonymouslyError: Error?
    /// When set, `signInWithApple(identityToken:nonce:)` throws this error.
    var signInWithAppleError: Error?
    /// When set, `signOut()` throws this error.
    var signOutError: Error?
    /// When set, `deleteAccount()` throws this error.
    var deleteAccountError: Error?
    /// When set, `startSessionIfNeeded()` and `restoreSession()` transition to this state instead of their default behaviour.
    var restoreStateAfterCall: AuthState?
    /// Backing value for `isAnonymous`. Defaults to `true`.
    var stubbedIsAnonymous: Bool

    var currentUserId: String? {
        switch authState {
        case .signedIn(let userId):
            return userId
        case .unknown, .signedOut:
            return nil
        }
    }

    var isAnonymous: Bool {
        stubbedIsAnonymous
    }

    var isAuthAvailable: Bool { true }

    /// - Parameters:
    ///   - initialState: The auth state the mock starts in. Defaults to `.signedOut`.
    ///   - stubbedAccessToken: Token returned by `accessToken()`. Defaults to `"mock-supabase-token"`.
    ///   - isAnonymous: Initial value for `isAnonymous`. Defaults to `true`.
    ///   - analyticsService: Optional analytics service for tracking events during mock flows.
    init(
        initialState: AuthState = .signedOut,
        stubbedAccessToken: String = "mock-supabase-token",
        isAnonymous: Bool = true,
        analyticsService: AnalyticsServiceProtocol? = nil
    ) {
        self.authStateBroadcaster = AsyncValueBroadcaster(initialState)
        self.stubbedAccessToken = stubbedAccessToken
        self.stubbedIsAnonymous = isAnonymous
        self.analyticsService = analyticsService
    }

    /// Returns `stubbedAccessToken` when signed in, or throws if `accessTokenError` is set or the state is not `.signedIn`.
    func accessToken() async throws -> String {
        if let accessTokenError {
            throw accessTokenError
        }
        guard case .signedIn = authState else {
            throw AuthError.notAuthenticated
        }
        return stubbedAccessToken
    }

    /// Simulates session bootstrap: transitions from `.signedOut` to an anonymous signed-in state,
    /// or applies `restoreStateAfterCall` if set.
    func startSessionIfNeeded() async {
        startSessionIfNeededCallCount += 1
        if let restoreStateAfterCall {
            authStateBroadcaster.send(restoreStateAfterCall)
        } else if case .signedOut = authState {
            stubbedIsAnonymous = true
            authStateBroadcaster.send(.signedIn(userId: "mock-anonymous-user"))
            analyticsService?.track(.anonymousAuthCompleted)
        }
    }

    /// Transitions to an anonymous signed-in state, or throws `signInAnonymouslyError` if set.
    func signInAnonymously() async throws {
        signInAnonymouslyCallCount += 1
        if let signInAnonymouslyError {
            throw signInAnonymouslyError
        }
        if case .signedIn = authState {
            return
        }
        stubbedIsAnonymous = true
        authStateBroadcaster.send(.signedIn(userId: "mock-anonymous-user"))
        analyticsService?.track(.anonymousAuthCompleted)
    }

    /// Transitions to a named (non-anonymous) signed-in state, or throws `signInWithAppleError` if set.
    func signInWithApple(identityToken: Data, nonce: String) async throws {
        signInWithAppleCallCount += 1
        if let signInWithAppleError {
            throw signInWithAppleError
        }
        stubbedIsAnonymous = false
        authStateBroadcaster.send(.signedIn(userId: "mock-apple-user"))
    }

    /// Transitions to `.signedOut`, or throws `signOutError` if set.
    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError {
            throw signOutError
        }
        stubbedIsAnonymous = true
        authStateBroadcaster.send(.signedOut)
    }

    /// Transitions to `.signedOut`, or throws `deleteAccountError` if set.
    func deleteAccount() async throws {
        deleteAccountCallCount += 1
        if let deleteAccountError {
            throw deleteAccountError
        }
        stubbedIsAnonymous = true
        authStateBroadcaster.send(.signedOut)
    }

    /// Applies `restoreStateAfterCall` if set; otherwise leaves state unchanged.
    func restoreSession() async {
        restoreSessionCallCount += 1
        if let restoreStateAfterCall {
            authStateBroadcaster.send(restoreStateAfterCall)
        }
    }

    /// Directly sets `authState`, bypassing method call tracking. Useful for arranging test preconditions.
    func setAuthState(_ newState: AuthState) {
        authStateBroadcaster.send(newState)
    }
}
#endif
