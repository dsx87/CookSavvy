//
//  DatabaseInitializationService.swift
//  CookSavvy
//
//  Created by Claude on 17/01/2026.
//

import Foundation
import os.log

enum DatabaseInitializationState: Equatable {
    case notStarted
    case loadingIngredients
    case loadingRecipes
    case ready
    case failed(String)
    
    var isIngredientsReady: Bool {
        switch self {
        case .loadingRecipes, .ready:
            return true
        default:
            return false
        }
    }
    
    var isRecipesReady: Bool {
        self == .ready
    }
}

final class DatabaseInitializationService: ObservableObject, DatabaseInitializationServiceProtocol {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "DatabaseInitialization"
    )
    
    @Published private(set) var state: DatabaseInitializationState = .notStarted
    
    private let dbInterface: DBInterfaceProtocol
    private let ingredientsService: IngredientsServiceProtocol
    private let dataImportService: DataImportServiceProtocol
    
    private var initializationTask: Task<Void, Never>?
    
    init(
        dbInterface: DBInterfaceProtocol,
        ingredientsService: IngredientsServiceProtocol,
        dataImportService: DataImportServiceProtocol
    ) {
        self.dbInterface = dbInterface
        self.ingredientsService = ingredientsService
        self.dataImportService = dataImportService
    }
    
    func startInitialization() {
        guard initializationTask == nil else {
            Self.logger.debug("Initialization already in progress, skipping")
            return
        }
        
        initializationTask = Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        Self.logger.info("Starting database initialization")
        
        state = .loadingIngredients
        Self.logger.info("Phase 1: Loading ingredients...")
        
        do {
            let ingredientsStartTime = Date()
            try await ingredientsService.ensureIngredientsLoaded()
            let ingredientsDuration = Date().timeIntervalSince(ingredientsStartTime)
            Self.logger.info("Ingredients loaded successfully in \(String(format: "%.2f", ingredientsDuration))s")
        } catch {
            Self.logger.error("Failed to load ingredients: \(error.localizedDescription)")
            state = .failed("Failed to load ingredients: \(error.localizedDescription)")
            return
        }
        
        state = .loadingRecipes
        Self.logger.info("Phase 2: Loading recipes...")
        
        do {
            let recipesStartTime = Date()
            try await dataImportService.ensureRecipesImported()
            let recipesDuration = Date().timeIntervalSince(recipesStartTime)
            Self.logger.info("Recipes loaded successfully in \(String(format: "%.2f", recipesDuration))s")
        } catch {
            Self.logger.error("Failed to load recipes: \(error.localizedDescription)")
            state = .failed("Failed to load recipes: \(error.localizedDescription)")
            return
        }
        
        state = .ready
        Self.logger.info("Database initialization completed successfully")
    }
    
    func waitForIngredients() async {
        while !state.isIngredientsReady {
            if case .failed = state {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
    
    func waitForRecipes() async {
        while !state.isRecipesReady {
            if case .failed = state {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    #if DEBUG
    func markReadyForTesting() {
        initializationTask?.cancel()
        initializationTask = nil
        state = .ready
    }
    #endif
}
