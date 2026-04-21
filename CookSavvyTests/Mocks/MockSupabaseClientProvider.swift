//
//  MockSupabaseClientProvider.swift
//  CookSavvyTests
//

import Foundation
import Supabase
@testable import CookSavvy

final class MockSupabaseClientProvider: SupabaseClientProviderProtocol {
    let client: SupabaseClient

    private(set) var invokedFunctionNames: [String] = []
    private(set) var invokedFunctionBodies: [String: Data] = [:]

    var stubbedResponses: [String: Data] = [:]
    var invokedError: Error?

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
