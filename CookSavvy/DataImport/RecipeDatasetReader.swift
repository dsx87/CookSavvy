//
//  RecipeDatasetReader.swift
//  CookSavvy
//
//  Created by Codex on 25/04/2026.
//

import Foundation
import ZIPFoundation

/// Reads the bundled offline recipe dataset and converts archive contents into app models.
protocol RecipeDatasetReading {
    /// Returns `true` when the URL points to a ZIP archive containing `recipes.json`.
    func canReadDataset(at url: URL) -> Bool
    /// Extracts and decodes every recipe from the archive's `recipes.json` entry.
    func readRecipes(from zipURL: URL) throws -> [Recipe]
}

/// ZIP-backed reader for the canonical bundled JSON recipe dataset.
///
/// The archive stores a root `recipes.json` file plus image assets under nested paths such as
/// `images/example.jpg`. The reader owns only recipe decoding; image extraction remains lazy in
/// `ImageService`, using the image paths preserved on each decoded recipe.
final class JSONRecipeDatasetReader: RecipeDatasetReading {
    private enum Constants {
        static let recipeFileName = "recipes.json"
        static let zipExtension = "zip"
    }

    private let decoder: JSONDecoder

    /// Creates a JSON dataset reader with an injectable decoder for focused tests.
    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    func canReadDataset(at url: URL) -> Bool {
        guard url.pathExtension.lowercased() == Constants.zipExtension,
              let archive = Archive(url: url, accessMode: .read) else {
            return false
        }

        return recipeEntry(in: archive) != nil
    }

    func readRecipes(from zipURL: URL) throws -> [Recipe] {
        guard zipURL.pathExtension.lowercased() == Constants.zipExtension,
              let archive = Archive(url: zipURL, accessMode: .read) else {
            throw RecipeDatasetReaderError.invalidArchive
        }

        guard let entry = recipeEntry(in: archive) else {
            throw RecipeDatasetReaderError.recipesFileNotFound
        }

        let data = try extract(entry, from: archive)
        let recipes = try decodeRecipes(from: data)
        guard !recipes.isEmpty else {
            throw RecipeDatasetReaderError.emptyDataset
        }
        return recipes
    }

    /// Locates the recipe manifest while tolerating a containing folder created by ZIP tools.
    private func recipeEntry(in archive: Archive) -> Entry? {
        archive.first { entry in
            guard entry.type == .file else { return false }
            let path = entry.path.lowercased()
            return path == Constants.recipeFileName || path.hasSuffix("/\(Constants.recipeFileName)")
        }
    }

    /// Extracts ZIP entry bytes in memory so the reader does not need temporary files.
    private func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    /// Decodes the canonical lower-camel dataset DTO from `recipes.json`.
    private func decodeRecipes(from data: Data) throws -> [Recipe] {
        do {
            return try decoder.decode([RecipeDatasetDTO].self, from: data).map { $0.recipe }
        } catch {
            throw RecipeDatasetReaderError.decodingFailed(error)
        }
    }
}

/// Errors produced by the JSON dataset reader.
enum RecipeDatasetReaderError: Error, LocalizedError {
    /// The supplied file is not a readable ZIP archive.
    case invalidArchive
    /// The ZIP archive does not include a `recipes.json` manifest.
    case recipesFileNotFound
    /// `recipes.json` decoded successfully but did not contain any recipes.
    case emptyDataset
    /// The manifest exists but `recipes.json` could not be decoded.
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "Recipe dataset archive is not a readable ZIP file"
        case .recipesFileNotFound:
            return "Recipe dataset ZIP does not contain recipes.json"
        case .emptyDataset:
            return "Recipe dataset did not contain any recipes"
        case .decodingFailed(let error):
            return "Failed to decode recipe dataset: \(error.localizedDescription)"
        }
    }
}

/// Lower-camel JSON record used by the canonical bundled dataset.
private struct RecipeDatasetDTO: Decodable {
    let title: String
    let ingredients: [Ingredient]
    let instructions: [Recipe.Step]
    let image: String
    let additionalInfo: Recipe.AdditionalInfo?
    let cuisine: String?

    /// Converts the transport DTO into the app's runtime recipe model and marks it offline.
    var recipe: Recipe {
        Recipe(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            image: image,
            additionalInfo: additionalInfo ?? .empty,
            source: .offline,
            cuisine: cuisine
        )
    }
}
