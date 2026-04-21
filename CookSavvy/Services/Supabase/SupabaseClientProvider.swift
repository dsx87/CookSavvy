//
//  SupabaseClientProvider.swift
//  CookSavvy
//

import Foundation
import Supabase

protocol SupabaseClientProviderProtocol {
    var client: SupabaseClient { get }
    func invokeFunction<Request: Encodable>(_ name: String, body: Request) async throws -> Data
}

final class SupabaseClientProvider: SupabaseClientProviderProtocol {
    let client: SupabaseClient

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

    func invokeFunction<Request: Encodable>(_ name: String, body: Request) async throws -> Data {
        try await client.functions.invoke(
            name,
            options: FunctionInvokeOptions(body: body),
            decode: { data, _ in data }
        )
    }
}
