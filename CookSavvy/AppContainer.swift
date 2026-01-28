//
//  AppContainer.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import Foundation

/// Dependency injection container holding shared service instances

final class AppContainer {

    // TODO: redo this in non singleton way
    static let shared: AppContainer = AppContainer()
    
    // MARK: - Services
    let dbInterface: DBInterfaceProtocol
    let ingredientsService: IngredientsService
    let recipeService: RecipeService
    let imageService: ImageService
    let dataImportService: DataImportService
    let userDataService: UserDataService
    let databaseInitService: DatabaseInitializationService
    let ingredientDetectionService: IngredientDetectionServiceProtocol

    // MARK: - Initialization

    private init() {
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
        self.ingredientDetectionService = MockIngredientDetectionService()
        
        databaseInitService.startInitialization()
    }

}
