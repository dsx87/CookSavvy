//
//  MockAuthService.swift
//  CookSavvy
//

import Combine
import Foundation

#if DEBUG
final class MockAuthService: AuthServiceProtocol {
    @Published private(set) var authState: AuthState
    private let analyticsService: AnalyticsServiceProtocol?
    private(set) var signInAnonymouslyCallCount = 0
    private(set) var signInWithAppleCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var restoreSessionCallCount = 0
    private(set) var startSessionIfNeededCallCount = 0

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    var stubbedAccessToken: String
    var accessTokenError: Error?
    var signInAnonymouslyError: Error?
    var signInWithAppleError: Error?
    var signOutError: Error?
    var restoreStateAfterCall: AuthState?
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

    init(
        initialState: AuthState = .signedOut,
        stubbedAccessToken: String = "mock-supabase-token",
        isAnonymous: Bool = true,
        analyticsService: AnalyticsServiceProtocol? = nil
    ) {
        self.authState = initialState
        self.stubbedAccessToken = stubbedAccessToken
        self.stubbedIsAnonymous = isAnonymous
        self.analyticsService = analyticsService
    }

    func accessToken() async throws -> String {
        if let accessTokenError {
            throw accessTokenError
        }
        guard case .signedIn = authState else {
            throw AuthError.notAuthenticated
        }
        return stubbedAccessToken
    }

    func startSessionIfNeeded() async {
        startSessionIfNeededCallCount += 1
        if let restoreStateAfterCall {
            authState = restoreStateAfterCall
        } else if case .signedOut = authState {
            stubbedIsAnonymous = true
            authState = .signedIn(userId: "mock-anonymous-user")
            analyticsService?.track(.anonymousAuthCompleted)
        }
    }

    func signInAnonymously() async throws {
        signInAnonymouslyCallCount += 1
        if let signInAnonymouslyError {
            throw signInAnonymouslyError
        }
        if case .signedIn = authState {
            return
        }
        stubbedIsAnonymous = true
        authState = .signedIn(userId: "mock-anonymous-user")
        analyticsService?.track(.anonymousAuthCompleted)
    }

    func signInWithApple(identityToken: Data, nonce: String) async throws {
        signInWithAppleCallCount += 1
        if let signInWithAppleError {
            throw signInWithAppleError
        }
        stubbedIsAnonymous = false
        authState = .signedIn(userId: "mock-apple-user")
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError {
            throw signOutError
        }
        stubbedIsAnonymous = true
        authState = .signedOut
    }

    func restoreSession() async {
        restoreSessionCallCount += 1
        if let restoreStateAfterCall {
            authState = restoreStateAfterCall
        }
    }

    func setAuthState(_ newState: AuthState) {
        authState = newState
    }
}
#endif
