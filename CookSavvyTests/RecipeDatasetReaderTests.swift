//
//  RecipeDatasetReaderTests.swift
//  CookSavvyTests
//
//  Created by Codex on 25/04/2026.
//

import XCTest
import Foundation
import ZIPFoundation
@testable import CookSavvy

final class RecipeDatasetReaderTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }

    func testReaderCanDetectSupportedJSONArchive() throws {
        let zipURL = try makeDatasetZip(recipeJSON: makeRecipeJSONArray())
        let reader = JSONRecipeDatasetReader()

        XCTAssertTrue(reader.canReadDataset(at: zipURL))
    }

    func testReaderRejectsNonZipArchive() throws {
        let directory = try makeTemporaryDirectory()
        let url = directory.appendingPathComponent("dataset.txt")
        try Data("not a zip".utf8).write(to: url)
        let reader = JSONRecipeDatasetReader()

        XCTAssertFalse(reader.canReadDataset(at: url))
        XCTAssertThrowsError(try reader.readRecipes(from: url))
    }

    func testReaderRejectsZipWithoutRecipesJSON() throws {
        let zipURL = try makeDatasetZip(recipeJSON: nil)
        let reader = JSONRecipeDatasetReader()

        XCTAssertFalse(reader.canReadDataset(at: zipURL))
        XCTAssertThrowsError(try reader.readRecipes(from: zipURL)) { error in
            XCTAssertTrue(error is RecipeDatasetReaderError)
        }
    }

    func testReaderDecodesStructuredRecipeJSONAndPreservesImagePath() throws {
        let zipURL = try makeDatasetZip(recipeJSON: makeRecipeJSONArray())
        let recipes = try JSONRecipeDatasetReader().readRecipes(from: zipURL)

        XCTAssertEqual(recipes.count, 1)
        let recipe = try XCTUnwrap(recipes.first)
        XCTAssertEqual(recipe.title, "Nested Image Pasta")
        XCTAssertEqual(recipe.ingredients.map(\.name), ["pasta", "tomato"])
        XCTAssertEqual(recipe.instructions.map(\.text), ["Boil pasta.", "Toss with sauce."])
        XCTAssertEqual(recipe.instructions.first?.timerMinutes, 8)
        XCTAssertEqual(recipe.image, "images/nested-image-pasta.jpg")
        XCTAssertEqual(recipe.source, .offline)
    }

    func testReaderDecodesLegacyRecipeModelJSON() throws {
        let json = """
        [
          {
            "Title": "Legacy Dataset Soup",
            "Ingredients": "'water', 'salt'",
            "Instructions": "Boil water.\\nSeason.",
            "Image_Name": "images/legacy-dataset-soup.jpg",
            "Cleaned_Ingredients": "'water', 'salt'"
          }
        ]
        """
        let zipURL = try makeDatasetZip(recipeJSON: json)
        let recipes = try JSONRecipeDatasetReader().readRecipes(from: zipURL)

        XCTAssertEqual(recipes.first?.title, "Legacy Dataset Soup")
        XCTAssertEqual(recipes.first?.image, "images/legacy-dataset-soup.jpg")
        XCTAssertEqual(recipes.first?.source, .offline)
    }

    func testReaderReportsBothDecodeErrorsWhenSupportedShapesFail() throws {
        let json = """
        [
          {
            "title": "Broken Recipe",
            "ingredients": "not structured",
            "instructions": 42,
            "image": "images/broken.jpg",
            "cleanedIngredients": false
          }
        ]
        """
        let zipURL = try makeDatasetZip(recipeJSON: json)

        XCTAssertThrowsError(try JSONRecipeDatasetReader().readRecipes(from: zipURL)) { error in
            guard case RecipeDatasetReaderError.decodingFailed(let primary, let fallback) = error else {
                return XCTFail("Expected decodingFailed, got \(error)")
            }
            XCTAssertFalse(primary.localizedDescription.isEmpty)
            XCTAssertFalse(fallback.localizedDescription.isEmpty)
            XCTAssertTrue((error as? RecipeDatasetReaderError)?.errorDescription?.contains("Recipe model error") == true)
            XCTAssertTrue((error as? RecipeDatasetReaderError)?.errorDescription?.contains("Dataset DTO error") == true)
        }
    }

    private func makeRecipeJSONArray() -> String {
        """
        [
          {
            "title": "Nested Image Pasta",
            "ingredients": [
              { "name": "pasta" },
              { "name": "tomato" }
            ],
            "instructions": [
              { "text": "Boil pasta.", "timerMinutes": 8 },
              { "text": "Toss with sauce." }
            ],
            "image": "images/nested-image-pasta.jpg"
          }
        ]
        """
    }

    private func makeDatasetZip(recipeJSON: String?) throws -> URL {
        let fileManager = FileManager.default
        let directory = try makeTemporaryDirectory()
        let workDirectory = directory.appendingPathComponent("work", isDirectory: true)
        let imagesDirectory = workDirectory.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        if let recipeJSON {
            try Data(recipeJSON.utf8).write(to: workDirectory.appendingPathComponent("recipes.json"))
        } else {
            try Data("{}".utf8).write(to: workDirectory.appendingPathComponent("metadata.json"))
        }

        try Data("image bytes".utf8).write(to: imagesDirectory.appendingPathComponent("nested-image-pasta.jpg"))

        let zipURL = directory.appendingPathComponent("dataset.zip")
        try fileManager.zipItem(at: workDirectory, to: zipURL)
        return zipURL
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecipeDatasetReaderTests_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }
}
