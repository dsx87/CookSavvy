//
//  AppleSignInManager.swift
//  CookSavvy
//

import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// The credential returned by a successful Sign in with Apple flow.
struct AppleSignInResult {
    /// The raw JWT identity token from Apple's authorization response.
    let identityToken: Data
    /// The plaintext nonce used when creating the authorization request.
    /// Must be passed to `SupabaseAuthService.signInWithApple(identityToken:nonce:)` alongside the token.
    let nonce: String
    /// The user's name components, available only on the first authorization for a given app.
    let fullName: PersonNameComponents?
    /// The user's email address, available only on the first authorization for a given app.
    let email: String?
}

/// Protocol for objects that can present the Sign in with Apple UI and return a credential.
protocol AppleSignInManaging: AnyObject {
    /// Presents the Sign in with Apple authorization sheet and returns the resulting credential.
    /// - Throws: `AuthError.signInCancelled` if the user dismisses the sheet, `AuthError.signInFailed` otherwise.
    func signIn() async throws -> AppleSignInResult
}

/// Concrete `ASAuthorizationController`-based implementation of the Sign in with Apple UI flow.
///
/// The nonce mechanism is required by Apple's SIWA spec to prevent replay attacks:
/// 1. A cryptographically-random plaintext nonce is generated with `randomNonceString()`.
/// 2. Its SHA256 hash is embedded in the `ASAuthorizationAppleIDRequest` sent to Apple.
/// 3. Apple signs the hash into the returned JWT identity token.
/// 4. Supabase verifies the hash when it receives the token, confirming the request originated from this app.
/// 5. The **plaintext** nonce is passed alongside the token to `SupabaseAuthService` so Supabase can
///    re-hash it for comparison.
///
/// The async/await interface is bridged to `ASAuthorizationControllerDelegate` via a
/// `CheckedContinuation`, which is held in `continuation` for the lifetime of the authorization UI.
final class AppleSignInManager: NSObject, AppleSignInManaging {

    /// Bridges the delegate callbacks back to the `async` caller. Held for the duration of the auth flow.
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    /// The plaintext nonce for the in-flight request, retained so it can be included in the result.
    private var currentNonce: String?

    /// Generates a nonce, presents the Apple authorization sheet, and returns the signed credential.
    ///
    /// Guards against concurrent calls by checking `continuation != nil`. The nonce is hashed with
    /// SHA256 before being sent to Apple; the plaintext is stored in `currentNonce` and returned
    /// with the result so `SupabaseAuthService` can pass it to Supabase for verification.
    /// - Throws: `AuthError.signInFailed` if a sign-in is already in progress or an unexpected error occurs.
    ///           `AuthError.signInCancelled` if the user dismisses the sheet.
    func signIn() async throws -> AppleSignInResult {
        guard continuation == nil else {
            throw AuthError.signInFailed
        }

        let nonce = Self.randomNonceString()
        currentNonce = nonce

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    /// Generates a cryptographically-random URL-safe string of the given length.
    ///
    /// Uses rejection sampling to eliminate modulo bias: bytes above the highest multiple of
    /// `charsetCount` that fits in a `UInt8` are discarded, ensuring every character in the
    /// charset has an equal probability of being selected.
    ///
    /// Example: charset has 64 characters, `maxUsable = 255 - (255 % 64) = 191`. Bytes 192–255
    /// are rejected. Each accepted byte is mapped via `byte % 64`, giving uniform distribution.
    /// - Parameter length: The desired nonce length in characters. Must be greater than 0.
    /// - Returns: A random alphanumeric-plus-punctuation string suitable for use as a SIWA nonce.
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let charsetCount = UInt8(charset.count)
        let maxUsable = UInt8.max - (UInt8.max % charsetCount) // rejection threshold
        var result: [Character] = []
        result.reserveCapacity(length)
        while result.count < length {
            var byte: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            precondition(errorCode == errSecSuccess, "Unable to generate random nonce")
            if byte <= maxUsable {
                result.append(charset[Int(byte % charsetCount)])
            }
        }
        return String(result)
    }

    /// Returns the lowercase hex-encoded SHA256 hash of `input`.
    /// This hash is sent to Apple in the authorization request; Apple signs it into the returned JWT.
    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#if DEBUG
/// DEBUG-only mock that returns a preset `AppleSignInResult` without presenting any UI.
final class MockAppleSignInManager: AppleSignInManaging {
    /// Number of times `signIn()` has been called.
    var signInCallCount = 0
    /// The result returned by `signIn()` unless `error` is set.
    var result = AppleSignInResult(
        identityToken: Data("debug-mock-identity-token".utf8),
        nonce: "debug-mock-nonce",
        fullName: nil,
        email: nil
    )
    /// When set, `signIn()` throws this error instead of returning `result`.
    var error: Error?

    /// Returns the configured mock result and tracks invocation count for tests.
    func signIn() async throws -> AppleSignInResult {
        signInCallCount += 1
        if let error {
            throw error
        }
        return result
    }
}
#endif

/// UIKit presentation anchor bridge for the Sign in with Apple controller.
extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {

    /// Returns the key window to use as the presentation anchor for the Apple sign-in sheet.
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

/// Delegate callbacks that resume the in-flight sign-in continuation.
extension AppleSignInManager: ASAuthorizationControllerDelegate {

    /// Packages the Apple credential into an `AppleSignInResult` and resumes the waiting continuation.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let nonce = currentNonce else {
                continuation?.resume(throwing: AuthError.signInFailed)
                continuation = nil
                return
            }

            let result = AppleSignInResult(
                identityToken: tokenData,
                nonce: nonce,
                fullName: credential.fullName,
                email: credential.email
            )
            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    /// Resumes the continuation with `AuthError.signInCancelled` for user cancellations, or
    /// `AuthError.signInFailed` for all other errors.
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if let asError = error as? ASAuthorizationError,
               asError.code == .canceled {
                continuation?.resume(throwing: AuthError.signInCancelled)
            } else {
                continuation?.resume(throwing: AuthError.signInFailed)
            }
            continuation = nil
        }
    }
}
