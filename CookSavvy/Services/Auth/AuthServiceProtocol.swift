//
//  AuthServiceProtocol.swift
//  CookSavvy
//

import Combine
import Foundation

enum AuthState: Equatable {
    case unknown
    case signedOut
    case signedIn(userId: String)
}

enum AuthError: Error, LocalizedError {
    case signInFailed
    case signInCancelled
    case signOutFailed
    case sessionUnavailable
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Sign in failed"
        case .signInCancelled:
            return "Sign in was cancelled"
        case .signOutFailed:
            return "Sign out failed"
        case .sessionUnavailable:
            return "Session is unavailable"
        case .notAuthenticated:
            return "Authentication is required"
        }
    }
}

protocol AuthServiceProtocol: AnyObject {
    var authState: AuthState { get }
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    var currentUserId: String? { get }
    var isAnonymous: Bool { get }
    var isAuthAvailable: Bool { get }

    func accessToken() async throws -> String
    func startSessionIfNeeded() async
    func signInAnonymously() async throws
    func signInWithApple(identityToken: Data, nonce: String) async throws
    func signOut() async throws
    func restoreSession() async
}
