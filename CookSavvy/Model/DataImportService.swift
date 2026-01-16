//
//  DataImportService.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation

final class DataImportService {

    // MARK: - Properties

    private let dbInterface: DBInterfaceProtocol
    private let csvReader: CSVToJSONReader

    private var isRecipesImported: Bool = false

    // MARK: - Initialization

    init(dbInterface: DBInterfaceProtocol, csvReader: CSVToJSONReader = CSVToJSONReader()) {
        self.dbInterface = dbInterface
        self.csvReader = csvReader
    }

    // MARK: - Public Methods

    /// Ensures recipes are imported into the database from the CSV dataset
    /// - Throws: Error if import fails
    func ensureRecipesImported() async throws {
        // Check if recipes already exist in database
        let commonIngredients = try dbInterface.searchIngredients(matching: "a", limit: 1)

        print("🔍 Checking for existing recipes...")

        if !commonIngredients.isEmpty {
            let existingRecipes = try dbInterface.getRecipes(byIngredients: commonIngredients)

            if !existingRecipes.isEmpty {
                print("✅ Recipes already imported (\(existingRecipes.count) found)")
                isRecipesImported = true
                return
            }
        }

        print("📥 Importing recipes from dataset...")

        guard let zipURL = Bundle.main.url(
            forResource: "food-ingredients-and-recipe-dataset-with-images",
            withExtension: "zip"
        ) else {
            throw DataImportError.datasetNotFound
        }

        let importedRecipes: [Recipe] = try csvReader.parseCSVFromZip(
            zipURL: zipURL,
            csvFilename: "Food Ingredients and Recipe Dataset with Image Name Mapping.csv",
            useCache: true
        )

        print("📊 Parsed \(importedRecipes.count) recipes from CSV")

        try dbInterface.insertRecipes(importedRecipes)

        print("✅ Successfully imported \(importedRecipes.count) recipes to database")
        isRecipesImported = true
    }

    /// Forces a re-import of recipes from the CSV dataset
    /// - Throws: Error if import fails
    func forceReimportRecipes() async throws {
        isRecipesImported = false
        try await ensureRecipesImported()
    }
}

// MARK: - Error Types

enum DataImportError: Error, LocalizedError {
    case datasetNotFound
    case importFailed(Error)

    var errorDescription: String? {
        switch self {
        case .datasetNotFound:
            return "Recipe dataset ZIP file not found in bundle"
        case .importFailed(let error):
            return "Failed to import data: \(error.localizedDescription)"
        }
    }
}
