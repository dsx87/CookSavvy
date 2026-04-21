//
//  SupabaseProviderTests.swift
//  CookSavvyTests
//

import XCTest
import Supabase
@testable import CookSavvy

final class SupabaseLLMProviderTests: XCTestCase {

    func testSendChatRequestDecodesSuccessfulResponse() async throws {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.stubbedResponses["generate-recipes"] = """
        {
          "content": "{\\"recipes\\":[{\\"title\\":\\"Soup\\"}]}",
          "tokens_used": {
            "prompt_tokens": 11,
            "completion_tokens": 7,
            "total_tokens": 18
          }
        }
        """.data(using: .utf8)!

        let provider = SupabaseLLMProvider(clientProvider: clientProvider)
        let response = try await provider.sendChatRequest(
            messages: [LLMMessage(role: .user, content: "hello")],
            responseFormat: .json
        )

        XCTAssertEqual(clientProvider.invokedFunctionNames, ["generate-recipes"])
        XCTAssertEqual(response.content, #"{"recipes":[{"title":"Soup"}]}"#)
        XCTAssertEqual(response.tokensUsed?.totalTokens, 18)
    }

    func testSendVisionRequestMapsHTTP400ToInvalidRequest() async {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.invokedError = FunctionsError.httpError(
            code: 400,
            data: Data("bad request".utf8)
        )

        let provider = SupabaseLLMProvider(clientProvider: clientProvider)

        do {
            _ = try await provider.sendVisionRequest(
                imageData: Data([0xFF, 0xD8, 0xFF]),
                mimeType: "image/jpeg",
                prompt: "Detect",
                responseFormat: .json
            )
            XCTFail("Expected invalidRequest error")
        } catch let error as LLMProviderError {
            guard case .invalidRequest(let message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(message, "bad request")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendChatRequestMapsHTTP401ToUnknownAuthError() async {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.invokedError = FunctionsError.httpError(code: 401, data: Data())

        let provider = SupabaseLLMProvider(clientProvider: clientProvider)

        do {
            _ = try await provider.sendChatRequest(
                messages: [LLMMessage(role: .user, content: "hello")],
                responseFormat: .json
            )
            XCTFail("Expected auth error")
        } catch let error as LLMProviderError {
            guard case .unknown(let underlyingError) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(underlyingError as? CookSavvy.AuthError, CookSavvy.AuthError.notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendChatRequestMapsHTTP429ToRateLimitExceeded() async {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.invokedError = FunctionsError.httpError(code: 429, data: Data())

        let provider = SupabaseLLMProvider(clientProvider: clientProvider)

        do {
            _ = try await provider.sendChatRequest(
                messages: [LLMMessage(role: .user, content: "hello")],
                responseFormat: .json
            )
            XCTFail("Expected rate limit error")
        } catch let error as LLMProviderError {
            guard case .rateLimitExceeded = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class SupabaseRecipeAPIProviderTests: XCTestCase {

    func testFetchRecipesDecodesSuccessfulResponse() async throws {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.stubbedResponses["search-recipes"] = """
        {
          "recipes": [
            {
              "title": "Chicken Rice Bowl",
              "ingredients": ["chicken", "rice"],
              "instructions": ["Cook rice", "Cook chicken"],
              "image": "https://example.com/recipe.png",
              "time": "25 min",
              "servings": 2,
              "complexity": "Easy",
              "calories": 450,
              "tagline": "Weeknight dinner",
              "author": "CookSavvy",
              "cuisine": "Asian",
              "match_percentage": 95,
              "match_reason": "Uses your main ingredients",
              "missing_ingredients": ["soy sauce"]
            }
          ]
        }
        """.data(using: .utf8)!

        let provider = SupabaseRecipeAPIProvider(
            clientProvider: clientProvider,
            configuration: SupabaseConfiguration(
                projectURLString: "https://example.supabase.co",
                anonKey: "anon-key"
            )
        )

        let recipes = try await provider.fetchRecipes(for: [Ingredient(name: "chicken")], count: 1)

        XCTAssertEqual(clientProvider.invokedFunctionNames, ["search-recipes"])
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.title, "Chicken Rice Bowl")
        XCTAssertEqual(recipes.first?.author, "CookSavvy")
        XCTAssertEqual(recipes.first?.missingIngredients, ["soy sauce"])
    }

    func testFetchRecipesThrowsNoResultsForEmptyResponse() async {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.stubbedResponses["search-recipes"] = #"{"recipes":[]}"#.data(using: .utf8)!

        let provider = SupabaseRecipeAPIProvider(
            clientProvider: clientProvider,
            configuration: SupabaseConfiguration(
                projectURLString: "https://example.supabase.co",
                anonKey: "anon-key"
            )
        )

        do {
            _ = try await provider.fetchRecipes(for: [Ingredient(name: "chicken")], count: 1)
            XCTFail("Expected noResults")
        } catch let error as RecipeAPIProviderError {
            guard case .noResults = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchRecipesMapsHTTP401ToNotAuthenticated() async {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.invokedError = FunctionsError.httpError(code: 401, data: Data())

        let provider = SupabaseRecipeAPIProvider(
            clientProvider: clientProvider,
            configuration: SupabaseConfiguration(
                projectURLString: "https://example.supabase.co",
                anonKey: "anon-key"
            )
        )

        do {
            _ = try await provider.fetchRecipes(for: [Ingredient(name: "chicken")], count: 1)
            XCTFail("Expected notAuthenticated")
        } catch let error as RecipeAPIProviderError {
            guard case .notAuthenticated = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchRecipesMapsHTTP429ToRateLimitExceeded() async {
        let clientProvider = MockSupabaseClientProvider()
        clientProvider.invokedError = FunctionsError.httpError(code: 429, data: Data())

        let provider = SupabaseRecipeAPIProvider(
            clientProvider: clientProvider,
            configuration: SupabaseConfiguration(
                projectURLString: "https://example.supabase.co",
                anonKey: "anon-key"
            )
        )

        do {
            _ = try await provider.fetchRecipes(for: [Ingredient(name: "chicken")], count: 1)
            XCTFail("Expected rateLimitExceeded")
        } catch let error as RecipeAPIProviderError {
            guard case .rateLimitExceeded = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
