//
//  RecipeShareCardGeneratorTests.swift
//  CookSavvyTests
//

import UIKit
import XCTest
@testable import CookSavvy

final class RecipeShareCardGeneratorTests: XCTestCase {

    @MainActor
    private func makeRecipe(
        title: String = "Tomato Pasta",
        image: String = "tomato-pasta",
        additionalInfo: Recipe.AdditionalInfo = .mock
    ) -> Recipe {
        let ingredients = [
            Ingredient(name: "Tomato"),
            Ingredient(name: "Pasta"),
            Ingredient(name: "Basil")
        ]
        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: ["Cook pasta", "Toss with sauce"],
            image: image,
            additionalInfo: additionalInfo,
            emoji: "🍝"
        )
    }

    @MainActor
    func testGeneratesPNGWhenRecipeImageIsAvailable() async {
        let imageService = MockImageService()
        imageService.stubbedRecipeImage = solidImage(color: .systemRed)
        let generator = RecipeShareCardGenerator(imageService: imageService)

        let card = await generator.makeShareCard(for: makeRecipe())

        XCTAssertEqual(imageService.loadRecipeImageCallCount, 1)
        XCTAssertEqual(card.title, "Tomato Pasta")
        XCTAssertTrue(card.pngData.startsWithPNGHeader)
        XCTAssertGreaterThan(card.pngData.count, 0)
    }

    @MainActor
    func testGeneratesPNGWhenImageLoadingReturnsNil() async {
        let imageService = MockImageService()
        let generator = RecipeShareCardGenerator(imageService: imageService)

        let card = await generator.makeShareCard(for: makeRecipe())

        XCTAssertEqual(imageService.loadRecipeImageCallCount, 1)
        XCTAssertTrue(card.pngData.startsWithPNGHeader)
        XCTAssertGreaterThan(card.pngData.count, 0)
    }

    @MainActor
    func testLoadsLocalDatasetImageUsingExactJSONImagePath() async {
        let imageService = MockImageService()
        let expectedName = "images/tomato-pasta.jpg"
        imageService.stubbedNamedImages[expectedName] = solidImage(color: .systemGreen)
        let generator = RecipeShareCardGenerator(imageService: imageService)

        let card = await generator.makeShareCard(for: makeRecipe(image: expectedName))

        XCTAssertEqual(imageService.loadRecipeImageCallCount, 1)
        XCTAssertEqual(imageService.loadNamedImageCalls, [expectedName])
        XCTAssertTrue(card.pngData.startsWithPNGHeader)
        XCTAssertGreaterThan(card.pngData.count, 0)
    }

    @MainActor
    func testGeneratesPNGWithTitleAndEmptyMetadata() async {
        let imageService = MockImageService()
        imageService.shouldThrowRecipeImage = true
        let generator = RecipeShareCardGenerator(imageService: imageService)
        let recipe = makeRecipe(title: "Simple Toast", additionalInfo: .empty)

        let card = await generator.makeShareCard(for: recipe)

        XCTAssertEqual(card.title, "Simple Toast")
        XCTAssertTrue(card.pngData.startsWithPNGHeader)
        XCTAssertGreaterThan(card.pngData.count, 0)
    }

    @MainActor
    private func solidImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 500))
        }
    }
}

private extension Data {
    var startsWithPNGHeader: Bool {
        starts(with: [0x89, 0x50, 0x4E, 0x47])
    }
}
