//
//  SupabaseServiceAssemblyTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class SupabaseServiceAssemblyTests: XCTestCase {

    func testAssemblyCreatesSupabaseProvidersWhenConfigurationValid() {
        let configuration = SupabaseConfiguration(
            projectURLString: "https://example.supabase.co",
            anonKey: "anon-key"
        )
        var factoryCallCount = 0

        let assembly = SupabaseServiceAssembly(
            configuration: configuration,
            clientProviderFactory: { url, anonKey in
                factoryCallCount += 1
                XCTAssertEqual(url.absoluteString, "https://example.supabase.co")
                XCTAssertEqual(anonKey, "anon-key")
                return MockSupabaseClientProvider()
            }
        )

        XCTAssertEqual(factoryCallCount, 1)
        XCTAssertNotNil(assembly.clientProvider)
        XCTAssertTrue(assembly.llmProvider is SupabaseLLMProvider)
        XCTAssertTrue(assembly.recipeAPIProvider is SupabaseRecipeAPIProvider)
    }

    func testAssemblyDoesNotCreateProvidersWhenConfigurationInvalid() {
        let assembly = SupabaseServiceAssembly(
            configuration: SupabaseConfiguration(
                projectURLString: nil,
                anonKey: nil
            ),
            clientProviderFactory: { _, _ in
                XCTFail("Factory should not be called for invalid configuration")
                return MockSupabaseClientProvider()
            }
        )

        XCTAssertNil(assembly.clientProvider)
        XCTAssertNil(assembly.llmProvider)
        XCTAssertNil(assembly.recipeAPIProvider)
    }
}
