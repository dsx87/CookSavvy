//
//  SupabaseClientProvider.swift
//  CookSavvy
//

import Foundation
import Supabase

/// Abstraction over `SupabaseClient` that enables test mocking and decouples call sites
/// from the concrete `supabase-swift` SDK type.
protocol SupabaseClientProviderProtocol {
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
        options: SupabaseClientOptions = SupabaseClientOptions()
    ) {
        self.client = SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: anonKey,
            options: options
        )
    }

    /// Invokes the named edge function, returning the raw response bytes.
    /// The `decode` closure passes through `Data` directly, deferring JSON parsing to callers.
    func invokeFunction<Request: Encodable>(_ name: String, body: Request) async throws -> Data {
        try await client.functions.invoke(
            name,
            options: FunctionInvokeOptions(body: body),
            decode: { data, _ in data }
        )
    }
}
