//
//  AppleSignInManager.swift
//  CookSavvy
//

import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct AppleSignInResult {
    let identityToken: Data
    let nonce: String
    let fullName: PersonNameComponents?
    let email: String?
}

@MainActor
protocol AppleSignInManaging: AnyObject {
    func signIn() async throws -> AppleSignInResult
}

@MainActor
final class AppleSignInManager: NSObject, AppleSignInManaging {

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?

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

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

#if DEBUG
@MainActor
final class MockAppleSignInManager: AppleSignInManaging {
    var signInCallCount = 0
    var result = AppleSignInResult(
        identityToken: Data("debug-mock-identity-token".utf8),
        nonce: "debug-mock-nonce",
        fullName: nil,
        email: nil
    )
    var error: Error?

    func signIn() async throws -> AppleSignInResult {
        signInCallCount += 1
        if let error {
            throw error
        }
        return result
    }
}
#endif

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {

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
