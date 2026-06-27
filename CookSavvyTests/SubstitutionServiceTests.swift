//
//  SubstitutionServiceTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class SubstitutionServiceTests: XCTestCase {

    private var temporaryDirectories: [URL] = []

    @MainActor
    override func tearDown() async throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }

    @MainActor
    func testLocalCatalogLoaderDecodesCatalogFromFileURL() async throws {
        let fileURL = try makeCatalogFile(
            json: """
            [
              {
                "ingredient": "butter",
                "aliases": ["salted butter"],
                "substitutes": [
                  {
                    "ingredient": "olive oil",
                    "aliases": [],
                    "ratio": "3/4 amount",
                    "note": "Good for sauteing."
                  }
                ]
              }
            ]
            """
        )

        let catalog = try LocalSubstitutionCatalogLoader(
            fileURL: fileURL,
            logger: MockLogger()
        ).loadCatalog()

        XCTAssertEqual(catalog.count, 1)
        XCTAssertEqual(catalog.first?.ingredient, "butter")
        XCTAssertEqual(catalog.first?.aliases, ["salted butter"])
        XCTAssertEqual(catalog.first?.substitutes.first?.ingredient, "olive oil")
    }

    @MainActor
    func testLocalCatalogLoaderThrowsWhenFileIsMissing() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Substitutions.json")

        XCTAssertThrowsError(
            try LocalSubstitutionCatalogLoader(
                fileURL: missingURL,
                logger: MockLogger()
            ).loadCatalog()
        ) { error in
            guard case SubstitutionCatalogLoaderError.fileNotFound(let fileName) = error else {
                return XCTFail("Expected fileNotFound error, got \(error)")
            }
            XCTAssertEqual(fileName, "Substitutions.json")
        }
    }

    @MainActor
    func testSuggestionsPreferSubstituteUserAlreadyHas() async throws {
        let service = try makeService(
            json: """
            [
              {
                "ingredient": "butter",
                "aliases": ["salted butter", "unsalted butter"],
                "substitutes": [
                  {
                    "ingredient": "coconut oil",
                    "aliases": [],
                    "ratio": "1:1",
                    "note": "Can add a little coconut flavor."
                  },
                  {
                    "ingredient": "olive oil",
                    "aliases": [],
                    "ratio": "3/4 amount",
                    "note": "Best for sauteing."
                  }
                ]
              }
            ]
            """
        )

        let suggestions = try await service.suggestions(
            for: ["butter"],
            recipeIngredients: [Ingredient(name: "Butter")],
            availableIngredients: [Ingredient(name: "Olive Oil")]
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.missingIngredientName, "butter")
        XCTAssertEqual(suggestions.first?.options.map(\.ingredientName), ["olive oil", "coconut oil"])
        XCTAssertEqual(suggestions.first?.options.map(\.isAvailableFromUserIngredients), [true, false])
    }

    @MainActor
    func testSuggestionsResolveAliasesAgainstMissingIngredient() async throws {
        let service = try makeService(
            json: """
            [
              {
                "ingredient": "green onion",
                "aliases": ["scallion", "spring onion"],
                "substitutes": [
                  {
                    "ingredient": "chives",
                    "aliases": [],
                    "ratio": "1:1",
                    "note": "Great as a garnish."
                  }
                ]
              }
            ]
            """
        )

        let suggestions = try await service.suggestions(
            for: ["scallion"],
            recipeIngredients: [Ingredient(name: "Green Onion")],
            availableIngredients: []
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.missingIngredientName, "scallion")
        XCTAssertEqual(suggestions.first?.options.first?.ingredientName, "chives")
    }

    @MainActor
    func testSuggestionsReturnEmptyForUncoveredIngredients() async throws {
        let service = try makeService(
            json: """
            [
              {
                "ingredient": "milk",
                "aliases": [],
                "substitutes": [
                  {
                    "ingredient": "oat milk",
                    "aliases": [],
                    "ratio": "1:1",
                    "note": "Works in most cooking."
                  }
                ]
              }
            ]
            """
        )

        let suggestions = try await service.suggestions(
            for: ["saffron"],
            recipeIngredients: [Ingredient(name: "Saffron")],
            availableIngredients: []
        )

        XCTAssertTrue(suggestions.isEmpty)
    }

    @MainActor
    private func makeService(json: String) throws -> SubstitutionService {
        let fileURL = try makeCatalogFile(json: json)
        return SubstitutionService(
            loader: LocalSubstitutionCatalogLoader(
                fileURL: fileURL,
                logger: MockLogger()
            ),
            logger: MockLogger()
        )
    }

    @MainActor
    private func makeCatalogFile(json: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)

        let fileURL = directory.appendingPathComponent("Substitutions.json")
        try Data(json.utf8).write(to: fileURL)
        return fileURL
    }
}
