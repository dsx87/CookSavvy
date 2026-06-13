//
//  AuthServiceProtocol.swift
//  CookSavvy
//

import Foundation

/// Represents the current authentication state of the user.
enum AuthState: Equatable {
    /// Auth state has not yet been determined (e.g., session check in progress at startup).
    case unknown
    /// No active session exists.
    case signedOut
    /// An active session exists for the given user ID, which may be anonymous or Apple-linked.
    case signedIn(userId: String)
}

/// Errors that can be thrown by auth service operations.
enum AuthError: Error, LocalizedError {
    /// The sign-in attempt failed for a non-cancellation reason.
    case signInFailed
    /// The user cancelled the sign-in flow (e.g., dismissed the Apple sign-in sheet).
    case signInCancelled
    /// The sign-out request failed.
    case signOutFailed
    /// A valid session could not be obtained due to a transient or network issue.
    case sessionUnavailable
    /// The operation requires an authenticated session but none exists.
    case notAuthenticated
    /// Account deletion failed (network error or backend rejection).
    case accountDeletionFailed

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
        case .accountDeletionFailed:
            return "Account deletion failed"
        }
    }
}

/// Common interface for all authentication implementations.
///
/// CookSavvy uses a two-tier auth model:
/// 1. **Anonymous** — created automatically on first launch so the app can reach the API without user action.
/// 2. **Apple** — an optional upgrade that links the anonymous Supabase identity to an Apple ID,
///    making the account persistent across devices and re-installs.
///
/// Concrete implementations: `SupabaseAuthService` (production), `MockAuthService` (DEBUG/tests),
/// `NoOpAuthService` (RELEASE fallback when Supabase keys are absent).
protocol AuthServiceProtocol: AnyObject {
    /// The current synchronously-readable auth state.
    var authState: AuthState { get }
    /// A stream that replays the current `authState`, then yields every subsequent change.
    /// A fresh stream is returned per access (single-consumer `AsyncStream` semantics).
    var authStateUpdates: AsyncStream<AuthState> { get }
    /// The Supabase user ID for the active session, or `nil` when signed out or unknown.
    var currentUserId: String? { get }
    /// `true` when the current session belongs to an anonymous (non-Apple) Supabase user.
    var isAnonymous: Bool { get }
    /// `false` for `NoOpAuthService`, `true` for all real/mock implementations.
    var isAuthAvailable: Bool { get }

    /// Returns a valid JWT access token for API requests, refreshing the session if necessary.
    /// - Throws: `AuthError.notAuthenticated` if no session exists, `AuthError.sessionUnavailable` for transient failures.
    func accessToken() async throws -> String
    /// Ensures an active session exists, creating an anonymous one if needed. Safe to call on every app activation.
    func startSessionIfNeeded() async
    /// Creates a new anonymous Supabase session for the current device.
    /// - Throws: `AuthError.signInFailed` on failure.
    func signInAnonymously() async throws
    /// Links the current session (typically anonymous) to an Apple identity, upgrading it to a named account.
    /// - Parameters:
    ///   - identityToken: The raw JWT identity token from Apple's authorization response.
    ///   - nonce: The plaintext nonce whose SHA256 hash was sent in the original authorization request.
    /// - Throws: `AuthError.signInFailed` if the token is invalid or the link fails.
    func signInWithApple(identityToken: Data, nonce: String) async throws
    /// Signs out the current session.
    /// - Throws: `AuthError.signOutFailed` on failure.
    func signOut() async throws
    /// Permanently deletes the authenticated user's account and server-side data, then signs out.
    ///
    /// Required for App Store compliance (Guideline 5.1.1(v)). The deletion itself is performed by a
    /// backend (`delete-account` edge function) using a privileged server-side key; the client only
    /// invokes it with the current session's bearer token.
    /// - Throws: `AuthError.notAuthenticated` if no session exists, or `AuthError.accountDeletionFailed` on failure.
    func deleteAccount() async throws
    /// Attempts to restore an existing session from persistent storage without creating a new one.
    func restoreSession() async
}
