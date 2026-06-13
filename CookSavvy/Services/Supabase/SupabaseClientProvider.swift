//
//  SupabaseClientProvider.swift
//  CookSavvy
//

import Foundation
import Supabase

/// Abstraction over `SupabaseClient` that enables test mocking and decouples call sites
/// from the concrete `supabase-swift` SDK type.
nonisolated protocol SupabaseClientProviderProtocol: Sendable {
    /// The underlying Supabase client instance.
    var client: SupabaseClient { get }
    /// Invokes a named Supabase Edge Function with an `Encodable` request body and returns the raw response `Data`.
    /// - Parameters:
    ///   - name: The edge function name (e.g. `"detect-ingredients"`).
    ///   - body: An `Encodable` value serialized as the JSON request body.
    /// - Returns: Raw `Data` from the edge function response.
    /// - Throws: A `FunctionsError` or `AuthError` from the Supabase SDK on failure.
    func invokeFunction<Request: Encodable>(_ name: String, body: Request) async throws -> Data
}

/// Concrete `SupabaseClientProviderProtocol` implementation that owns the `SupabaseClient` instance.
final class SupabaseClientProvider: SupabaseClientProviderProtocol {
    /// The shared Supabase client configured with the project URL and anon key.
    let client: SupabaseClient

    /// Creates the `SupabaseClient` from the given project credentials.
    /// - Parameters:
    ///   - projectURL: The Supabase project URL.
    ///   - anonKey: The Supabase anon (publishable) key.
    ///   - options: Optional client configuration overrides.
    init(
        projectURL: URL,
        anonKey: String,
        options: SupabaseClientOptions = SupabaseClientOptions(
            // Opt into the next-major-release behavior: emit the locally stored session
            // immediately as the initial session rather than after a refresh attempt.
            // `syncStateFromCurrentSession` already guards against expired sessions via `isExpired`.
            auth: .init(emitLocalSessionAsInitialSession: true)
        )
    ) {
        self.client = SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: anonKey,
            options: options
        )
    }

    /// Invokes the named edge function, returning the raw response bytes.
    /// The `decode` closure passes through `Data` directly, deferring JSON parsing to callers.
    ///
    /// Explicitly sets the `Authorization: Bearer <accessToken>` header using the synchronous
    /// `currentSession` so that edge function JWT verification always receives a valid token,
    /// even when the SDK's async `_getAccessToken()` path (used by `fetchWithAuth`) silently
    /// fails due to a missing or expired session.
    func invokeFunction<Request: Encodable>(_ name: String, body: Request) async throws -> Data {
        var headers: [String: String] = [:]
        if let session = client.auth.currentSession, !session.isExpired {
            headers["Authorization"] = "Bearer \(session.accessToken)"
        }
        return try await client.functions.invoke(
            name,
            options: FunctionInvokeOptions(headers: headers, body: body),
            decode: { data, _ in data }
        )
    }
}
