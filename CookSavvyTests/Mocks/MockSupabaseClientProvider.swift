//
//  MockSupabaseClientProvider.swift
//  CookSavvyTests
//

import Foundation
import Supabase
@testable import CookSavvy

// Mocks a `nonisolated`, `Sendable` provider. Tracking state is mutated only from the serial test
// that owns the instance, so `nonisolated(unsafe)` is safe here.
final class MockSupabaseClientProvider: SupabaseClientProviderProtocol {
    let client: SupabaseClient

    nonisolated(unsafe) private(set) var invokedFunctionNames: [String] = []
    nonisolated(unsafe) private(set) var invokedFunctionBodies: [String: Data] = [:]

    nonisolated(unsafe) var stubbedResponses: [String: Data] = [:]
    nonisolated(unsafe) var invokedError: Error?

    init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "public-anon-key"
        )
    }

    func invokeFunction<Request: Encodable>(_ name: String, body: Request) async throws -> Data {
        invokedFunctionNames.append(name)
        invokedFunctionBodies[name] = try? JSONEncoder().encode(AnyEncodable(body))

        if let invokedError {
            throw invokedError
        }

        return stubbedResponses[name] ?? Data()
    }
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        self.encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
