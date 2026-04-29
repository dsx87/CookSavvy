//
//  FoodCatalogValidationTests.swift
//  CookSavvyTests
//
//  Created by Codex on 29/04/2026.
//

import XCTest
@testable import CookSavvy

final class FoodCatalogValidationTests: XCTestCase {
    func testFoodCatalogStrictlyParsesAndKeepsOnlyCookingFocusedEntries() throws {
        let ingredients = try loadFoodCatalog()
        let names = Set(ingredients.map(\.name))

        let removedSamples = [
            "Angelica",
            "Silver linden",
            "Allium",
            "Wild celery",
            "Fish oil",
            "Taco shell",
            "Tostada shell",
            "Bowhead whale",
            "Green turtle"
        ]

        for name in removedSamples {
            XCTAssertFalse(names.contains(name), "\(name) should not be present in the curated ingredient catalog.")
        }

        let keptSamples = [
            "Garden onion",
            "Garlic",
            "Pasta",
            "Butter",
            "Vinegar",
            "Cannellini bean"
        ]

        for name in keptSamples {
            XCTAssertTrue(names.contains(name), "\(name) should remain available in the curated ingredient catalog.")
        }
    }

    private func loadFoodCatalog() throws -> [Ingredient] {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CookSavvy/Support/Assets/Food.json")
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Ingredient].self, from: data)
    }
}
