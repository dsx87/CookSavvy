//
//  DataImportService.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation

private enum DataImportServiceConstants {
    static let populationProbe = "a"
    static let populationProbeLimit = 1
    static let existingRecipeLimit = 20
    static let datasetName = "food-ingredients-and-recipe-dataset-with-images"
    static let datasetExtension = "zip"
    static let datasetCSVName = "Food Ingredients and Recipe Dataset with Image Name Mapping.csv"
}

final class DataImportService: DataImportServiceProtocol {

    // MARK: - Properties

    private let dbInterface: DBInterfaceProtocol
    private let csvReader: CSVParser
    private let logger: any LoggerProtocol

    private var isRecipesImported: Bool = false

    // MARK: - Initialization

    init(
        dbInterface: DBInterfaceProtocol,
        csvReader: CSVParser = CSVParser(),
        logger: any LoggerProtocol
    ) {
        self.dbInterface = dbInterface
        self.csvReader = csvReader
        self.logger = logger
    }

    // MARK: - Public Methods

    /// Ensures recipes are imported into the database from the CSV dataset
    /// - Throws: Error if import fails
    func ensureRecipesImported() async throws {
        // Check if recipes already exist in database
        let commonIngredients = try dbInterface.searchIngredients(
            matching: DataImportServiceConstants.populationProbe,
            limit: DataImportServiceConstants.populationProbeLimit
        )

        logger.info("Checking for existing recipes")

        if !commonIngredients.isEmpty {
            let existingRecipes = try dbInterface.getRecipes(
                byIngredients: commonIngredients,
                offset: 0,
                limit: DataImportServiceConstants.existingRecipeLimit
            )

            if !existingRecipes.isEmpty {
                logger.info("Recipes already imported (\(existingRecipes.count) found)")
                isRecipesImported = true
                return
            }
        }

        logger.info("Importing recipes from dataset")

        guard let zipURL = Bundle.main.url(
            forResource: DataImportServiceConstants.datasetName,
            withExtension: DataImportServiceConstants.datasetExtension
        ) else {
            throw DataImportError.datasetNotFound
        }

        var importedRecipes: [Recipe] = try csvReader.parseCSVFromZip(
            zipURL: zipURL,
            csvFilename: DataImportServiceConstants.datasetCSVName
        )

        // TODO: optimize
        for i in importedRecipes.indices { importedRecipes[i].source = .offline }

        logger.info("Parsed \(importedRecipes.count) recipes from CSV")

        try dbInterface.insertRecipes(importedRecipes)

        logger.info("Successfully imported \(importedRecipes.count) recipes to database")
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
