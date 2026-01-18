//
//  AppContainer.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation

/// Dependency injection container holding shared service instances

final class AppContainer: ObservableObject {

    // MARK: - Services

    let dbInterface: DBInterfaceProtocol
    let ingredientsService: IngredientsService
    let recipeService: RecipeService
    let imageService: ImageService
    let dataImportService: DataImportService
    let userDataService: UserDataService
    let databaseInitService: DatabaseInitializationService

    // MARK: - Initialization

    init() {
        // Initialize database
        let db = DBInterface()
        self.dbInterface = db

        // Initialize services with dependencies
        let ingredients = IngredientsService(dbInterface: db)
        let dataImport = DataImportService(dbInterface: db)
        
        self.ingredientsService = ingredients
        self.recipeService = RecipeService(dbInterface: db)
        self.imageService = ImageService()
        self.dataImportService = dataImport
        self.userDataService = UserDataService(dbInterface: db)
        
        self.databaseInitService = DatabaseInitializationService(
            dbInterface: db,
            ingredientsService: ingredients,
            dataImportService: dataImport
        )
        
        databaseInitService.startInitialization()
    }

    /// Convenience initializer for testing with custom dependencies
    init(
        dbInterface: DBInterfaceProtocol,
        ingredientsService: IngredientsService? = nil,
        recipeService: RecipeService? = nil,
        imageService: ImageService? = nil,
        dataImportService: DataImportService? = nil,
        userDataService: UserDataService? = nil,
        databaseInitService: DatabaseInitializationService? = nil
    ) {
        self.dbInterface = dbInterface
        
        let ingredients = ingredientsService ?? IngredientsService(dbInterface: dbInterface)
        let dataImport = dataImportService ?? DataImportService(dbInterface: dbInterface)
        
        self.ingredientsService = ingredients
        self.recipeService = recipeService ?? RecipeService(dbInterface: dbInterface)
        self.imageService = imageService ?? ImageService()
        self.dataImportService = dataImport
        self.userDataService = userDataService ?? UserDataService(dbInterface: dbInterface)
        
        self.databaseInitService = databaseInitService ?? DatabaseInitializationService(
            dbInterface: dbInterface,
            ingredientsService: ingredients,
            dataImportService: dataImport
        )
    }
}
