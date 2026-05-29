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
        XCTAssertEqual(recipe.image, "images/nested-image-pasta.jpg")
        XCTAssertEqual(recipe.source, .offline)
    }

    func testReaderReportsDecodeErrorForInvalidJSON() throws {
        let json = """
        [
          {
            "title": "Broken Recipe",
            "ingredients": "not structured",
            "instructions": 42,
            "image": "images/broken.jpg"
          }
        ]
        """
        let zipURL = try makeDatasetZip(recipeJSON: json)

        XCTAssertThrowsError(try JSONRecipeDatasetReader().readRecipes(from: zipURL)) { error in
            guard case RecipeDatasetReaderError.decodingFailed(let underlying) = error else {
                return XCTFail("Expected decodingFailed, got \(error)")
            }
            XCTAssertFalse(underlying.localizedDescription.isEmpty)
            XCTAssertTrue((error as? RecipeDatasetReaderError)?.errorDescription?.contains("Failed to decode") == true)
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
              "Boil pasta.",
              "Toss with sauce."
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
