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

    @MainActor
    override func setUp() async throws {
        onlineSource = OnlineRecipeSource()
    }

    @MainActor
    override func tearDown() async throws {
        onlineSource = nil
    }

    @MainActor
    func testSourceType() async {
        XCTAssertEqual(onlineSource.sourceType, .online)
    }

    @MainActor
    func testIsAvailableReturnsFalseWithoutProvider() async {
        let available = await onlineSource.isAvailable()
        XCTAssertFalse(available, "Online source should be unavailable without a provider")
    }
    
    @MainActor
    func testIsAvailableReturnsTrueWithProvider() async {
        let source = OnlineRecipeSource(provider: MockRecipeAPIProvider())
        let available = await source.isAvailable()
        XCTAssertTrue(available, "Online source should be available with a provider")
    }
    
    @MainActor
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
    
    @MainActor
    func testInitWithProvider() async {
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

    @MainActor
    func testSourceType() async {
        let source = AIRecipeSource(aiService: MockAIService())
        XCTAssertEqual(source.sourceType, .ai)
    }

    @MainActor
    func testAIRecipeSourceIsAvailableWhenServiceIsAvailable() async {
        let mockService = MockAIService()
        mockService.isAvailable = true
        let source = AIRecipeSource(aiService: mockService)
        let available = await source.isAvailable()
        XCTAssertTrue(available)
    }

    @MainActor
    func testAIRecipeSourceIsUnavailableWhenServiceIsUnavailable() async {
        let mockService = MockAIService()
        mockService.isAvailable = false
        let source = AIRecipeSource(aiService: mockService)
        let available = await source.isAvailable()
        XCTAssertFalse(available, "AI source should be unavailable when no real LLM provider is configured")
    }

    @MainActor
    func testAIRecipeSourceFetchesFromAIService() async throws {
        let mockService = MockAIService()
        let source = AIRecipeSource(aiService: mockService)
        let ingredients: [Ingredient] = ["Chicken", "Rice"]

        let recipes = try await source.fetchRecipes(for: ingredients)
        XCTAssertFalse(recipes.isEmpty)
        XCTAssertTrue(mockService.generateRecipesCalled)
    }

    @MainActor
    func testAIRecipeSourcePropagatesErrors() async {
        let mockService = MockAIService()
        mockService.shouldThrow = true
        let source = AIRecipeSource(aiService: mockService)
        let ingredients: [Ingredient] = ["Chicken", "Rice"]

        do {
            _ = try await source.fetchRecipes(for: ingredients)
            XCTFail("Should throw an error")
        } catch {
            // Expected — error propagated from AI service
        }
    }

}

private final class MockAIService: AIServiceProtocol {
    var isAvailable: Bool = true
    var generateRecipesCalled = false
    var shouldThrow = false

    func detectIngredients(from imageData: Data) async throws -> [Ingredient] {
        return []
    }

    func generateRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] {
        generateRecipesCalled = true
        if shouldThrow {
            throw AIServiceError.noRecipesGenerated
        }
        return Recipe.mocks(count: count)
    }
}
