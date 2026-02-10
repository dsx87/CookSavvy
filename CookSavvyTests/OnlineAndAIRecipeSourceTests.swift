//
//  OnlineAndAIRecipeSourceTests.swift
//  CookSavvyTests
//
//  Created by Cascade on 01/10/2025.
//

import XCTest
@testable import CookSavvy

final class OnlineRecipeSourceTests: XCTestCase {
    
    var onlineSource: OnlineRecipeSource!
    
    override func setUpWithError() throws {
        onlineSource = OnlineRecipeSource()
    }
    
    override func tearDownWithError() throws {
        onlineSource = nil
    }
    
    func testSourceType() {
        XCTAssertEqual(onlineSource.sourceType, .online)
    }
    
    func testIsAvailableReturnsFalseWithoutProvider() async {
        let available = await onlineSource.isAvailable()
        XCTAssertFalse(available, "Online source should be unavailable without a provider")
    }
    
    func testIsAvailableReturnsTrueWithProvider() async {
        let source = OnlineRecipeSource(provider: MockRecipeAPIProvider())
        let available = await source.isAvailable()
        XCTAssertTrue(available, "Online source should be available with a provider")
    }
    
    func testFetchRecipesThrowsUnavailableError() async {
        let ingredients: [Ingredient] = ["Chicken", "Tomato"]
        
        do {
            _ = try await onlineSource.fetchRecipes(for: ingredients)
            XCTFail("Should throw unavailable error")
        } catch let error as RecipeSourceError {
            if case .sourceUnavailable(let type) = error {
                XCTAssertEqual(type, .online)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testInitWithProvider() {
        let source = OnlineRecipeSource(provider: MockRecipeAPIProvider(), resultCount: 10)
        XCTAssertEqual(source.sourceType, .online)
    }
}

private final class MockRecipeAPIProvider: RecipeAPIProviderProtocol {
    var name: String { "Mock" }
    func fetchRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] {
        return Recipe.mocks(count: count)
    }
    func isAvailable() async -> Bool { true }
}

final class AIRecipeSourceTests: XCTestCase {
    
    var aiSource: AIRecipeSource!
    
    override func setUpWithError() throws {
        aiSource = AIRecipeSource()
    }
    
    override func tearDownWithError() throws {
        aiSource = nil
    }
    
    func testSourceType() {
        XCTAssertEqual(aiSource.sourceType, .ai)
    }
    
    func testIsAvailableReturnsFalse() async {
        let available = await aiSource.isAvailable()
        XCTAssertFalse(available, "AI source should be unavailable until implemented")
    }
    
    func testFetchRecipesThrowsUnavailableError() async {
        let ingredients: [Ingredient] = ["Chicken", "Rice"]
        
        do {
            _ = try await aiSource.fetchRecipes(for: ingredients)
            XCTFail("Should throw unavailable error")
        } catch let error as RecipeSourceError {
            if case .sourceUnavailable(let type) = error {
                XCTAssertEqual(type, .ai)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCustomInitialization() {
        let customSource = AIRecipeSource(
            modelEndpoint: "https://custom.ai.com/generate",
            apiKey: "test-key"
        )
        XCTAssertEqual(customSource.sourceType, .ai)
    }
}
