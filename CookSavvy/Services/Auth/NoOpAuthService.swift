//
//  NoOpAuthService.swift
//  CookSavvy
//

import Combine
import Foundation

final class NoOpAuthService: AuthServiceProtocol {
    let authState: AuthState = .signedOut
    let currentUserId: String? = nil
    let isAnonymous: Bool = false
    let isAuthAvailable: Bool = false

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        Just(.signedOut).eraseToAnyPublisher()
    }

    func accessToken() async throws -> String {
        throw AuthError.notAuthenticated
    }

    func startSessionIfNeeded() async {}
    func signInAnonymously() async throws { throw AuthError.signInFailed }
    func signInWithApple(identityToken: Data, nonce: String) async throws { throw AuthError.signInFailed }
    func signOut() async throws {}
    func restoreSession() async {}
}
