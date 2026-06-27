//
//  SupabaseConfigurationTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class SupabaseConfigurationTests: XCTestCase {

    @MainActor
    func testIsConfiguredIsTrueForValidURLAndAnonKey() async {
        let configuration = SupabaseConfiguration(
            projectURLString: "https://example.supabase.co",
            anonKey: "anon-key"
        )

        XCTAssertTrue(configuration.isConfigured)
        XCTAssertEqual(configuration.projectURL?.absoluteString, "https://example.supabase.co")
        XCTAssertEqual(configuration.anonKey, "anon-key")
    }

    @MainActor
    func testIsConfiguredIsFalseForInvalidURL() async {
        let configuration = SupabaseConfiguration(
            projectURLString: "not a valid url",
            anonKey: "anon-key"
        )

        XCTAssertFalse(configuration.isConfigured)
        XCTAssertNil(configuration.projectURL)
    }

    @MainActor
    func testIsConfiguredIsFalseWhenAnonKeyMissing() async {
        let configuration = SupabaseConfiguration(
            projectURLString: "https://example.supabase.co",
            anonKey: nil
        )

        XCTAssertFalse(configuration.isConfigured)
    }
}
