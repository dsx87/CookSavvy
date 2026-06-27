//
//  RecipeSourceTests.swift
//  CookSavvyTests
//
//  Created by Cascade on 01/10/2025.
//

import XCTest
@testable import CookSavvy

final class RecipeSourceTests: XCTestCase {

    // MARK: - RecipeSourceType Tests
    
    @MainActor
    func testRecipeSourceTypeRawValues() async {
        XCTAssertEqual(RecipeSourceType.offline.rawValue, "Offline")
        XCTAssertEqual(RecipeSourceType.online.rawValue, "Online")
        XCTAssertEqual(RecipeSourceType.ai.rawValue, "AI")
    }
    
    @MainActor
    func testRecipeSourceTypeDisplayNames() async {
        XCTAssertEqual(RecipeSourceType.offline.displayName, "Offline")
        XCTAssertEqual(RecipeSourceType.online.displayName, "Online")
        XCTAssertEqual(RecipeSourceType.ai.displayName, "AI")
    }
    
    @MainActor
    func testRecipeSourceTypeAllCases() async {
        let allCases = RecipeSourceType.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.offline))
        XCTAssertTrue(allCases.contains(.online))
        XCTAssertTrue(allCases.contains(.ai))
    }
    
    @MainActor
    func testRecipeSourceTypeCodable() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for sourceType in RecipeSourceType.allCases {
            let encoded = try encoder.encode(sourceType)
            let decoded = try decoder.decode(RecipeSourceType.self, from: encoded)
            XCTAssertEqual(sourceType, decoded)
        }
    }
    
    // MARK: - RecipeSourceError Tests
    
    @MainActor
    func testRecipeSourceErrorDescriptions() async {
        let sourceUnavailableError = RecipeSourceError.sourceUnavailable(.online)
        XCTAssertEqual(sourceUnavailableError.errorDescription, "Recipe source 'Online' is currently unavailable")
        
        let noRecipesError = RecipeSourceError.noRecipesFound
        XCTAssertEqual(noRecipesError.errorDescription, "No recipes found for the provided ingredients")
        
        let invalidDataError = RecipeSourceError.invalidData
        XCTAssertEqual(invalidDataError.errorDescription, "Invalid data received from source")
    }
    
    @MainActor
    func testRecipeSourceErrorNetworkError() async {
        let underlyingError = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not Found"])
        let networkError = RecipeSourceError.networkError(underlyingError)
        
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription?.contains("Network error") ?? false)
    }
    
    @MainActor
    func testRecipeSourceErrorDatabaseError() async {
        let underlyingError = NSError(domain: "DBDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "DB Error"])
        let dbError = RecipeSourceError.databaseError(underlyingError)
        
        XCTAssertNotNil(dbError.errorDescription)
        XCTAssertTrue(dbError.errorDescription?.contains("Database error") ?? false)
    }
}
