//
//  DataImportService.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation

/// Internal constants used by ``DataImportService`` to locate and probe the bundled dataset.
private enum DataImportServiceConstants {
    static let populationProbe = "a"
    static let populationProbeLimit = 1
    static let existingRecipeLimit = 20
    static let datasetName = "food-ingredients-and-recipe-dataset-with-images"
    static let datasetExtension = "zip"
    static let datasetCSVName = "Food Ingredients and Recipe Dataset with Image Name Mapping.csv"
}

/// Orchestrates first-launch seeding of the local SQLite database from the bundled CSV dataset.
///
/// On each app start ``DatabaseInitializationService`` calls ``ensureRecipesImported()``, which
/// performs a lightweight probe (searching for a common ingredient) to detect whether data has
/// already been imported. If not, it extracts the bundled ZIP, parses the CSV, and bulk-inserts
/// all recipes via ``DBInterfaceProtocol``. The flag ``isRecipesImported`` prevents redundant
/// work within the same process lifetime.
final class DataImportService: DataImportServiceProtocol {

    // MARK: - Properties

    private let dbInterface: DBInterfaceProtocol
    private let csvReader: CSVParser
    private let logger: any LoggerProtocol

    private var isRecipesImported: Bool = false

    // MARK: - Initialization

    /// Creates a ``DataImportService`` with the given dependencies.
    /// - Parameters:
    ///   - dbInterface: The database interface used to probe for existing data and insert recipes.
    ///   - csvReader: The CSV parser used to decode the dataset. Defaults to a plain ``CSVParser``.
    ///   - logger: A scoped logger for import progress and error reporting.
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

    /// Ensures the recipe dataset has been imported into the database.
    ///
    /// Performs a lightweight probe by searching for a common ingredient. If matching recipes are
    /// found the method returns immediately. Otherwise it extracts the bundled ZIP archive, parses
    /// the CSV, and bulk-inserts all recipes. Subsequent calls within the same process lifetime
    /// return immediately via the in-memory ``isRecipesImported`` flag.
    ///
    /// - Throws: ``DataImportError/datasetNotFound`` if the ZIP is missing from the app bundle,
    ///   or any error thrown by the database or parser.
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

    /// Clears the in-memory import flag and re-runs ``ensureRecipesImported()``.
    ///
    /// Useful during development or after a dataset update to force a full re-import
    /// without restarting the app.
    /// - Throws: Any error thrown by ``ensureRecipesImported()``.
    func forceReimportRecipes() async throws {
        isRecipesImported = false
        try await ensureRecipesImported()
    }
}

// MARK: - Error Types

/// Errors thrown during dataset import operations.
enum DataImportError: Error, LocalizedError {
    /// The recipe dataset ZIP file was not found in the app bundle.
    case datasetNotFound
    /// The import operation failed due to an underlying error.
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
