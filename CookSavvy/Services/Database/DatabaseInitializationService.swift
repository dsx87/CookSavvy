//
//  DatabaseInitializationService.swift
//  CookSavvy
//
//  Created by Claude on 17/01/2026.
//

import Foundation
import os.log

/// Represents the current phase of the two-phase database initialisation sequence.
///
/// Progress flows linearly: `notStarted` → `loadingIngredients` → `loadingRecipes` → `ready`.
/// Any failure transitions to `.failed` with a human-readable message.
enum DatabaseInitializationState: Equatable {
    /// Initialisation has not yet been triggered.
    case notStarted
    /// Phase 1: the ingredients CSV is being imported into the `ingredients` table.
    case loadingIngredients
    /// Phase 2: the recipe dataset is being imported into the `recipes` table.
    case loadingRecipes
    /// Both phases completed successfully; all data is available.
    case ready
    /// An unrecoverable error occurred. The associated string describes the failure.
    case failed(String)
    
    /// `true` once the app has progressed past the ingredients loading phase.
    var isIngredientsReady: Bool {
        switch self {
        case .loadingRecipes, .ready:
            return true
        default:
            return false
        }
    }
    
    /// `true` only when the full initialisation sequence has completed successfully.
    var isRecipesReady: Bool {
        self == .ready
    }
}

/// Orchestrates the two-phase database startup sequence at app launch.
///
/// **Phase 1 — Ingredients**: calls `IngredientsServiceProtocol.ensureIngredientsLoaded()` to
/// import the ingredient CSV if the `ingredients` table is empty.
///
/// **Phase 2 — Recipes**: calls `DataImportServiceProtocol.ensureRecipesImported()` to
/// import the recipe dataset CSV if the `recipes` table is empty.
///
/// The service is fail-fast: any error transitions `state` to `.failed(message)` and
/// propagates upward so `AppContainer` can render a blocking error screen rather than
/// silently continuing with a broken or empty database.
///
/// Callers can `await waitForIngredients()` or `await waitForRecipes()` to suspend until
/// the corresponding phase is complete, enabling ordered startup of dependent services.
final class DatabaseInitializationService: ObservableObject, DatabaseInitializationServiceProtocol {
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "DatabaseInitialization"
    )
    
    /// The published initialisation state, observed by the app root to gate startup UI.
    @Published private(set) var state: DatabaseInitializationState = .notStarted
    
    private let dbInterface: DBInterfaceProtocol
    private let ingredientsService: IngredientsServiceProtocol
    private let dataImportService: DataImportServiceProtocol
    
    /// Tracks the in-flight initialisation task so `startInitialization()` is idempotent.
    private var initializationTask: Task<Void, Never>?
    
    /// Initialises the service with its three required collaborators.
    init(
        dbInterface: DBInterfaceProtocol,
        ingredientsService: IngredientsServiceProtocol,
        dataImportService: DataImportServiceProtocol
    ) {
        self.dbInterface = dbInterface
        self.ingredientsService = ingredientsService
        self.dataImportService = dataImportService
    }
    
    /// Begins the two-phase initialisation sequence. Subsequent calls are no-ops.
    func startInitialization() {
        guard initializationTask == nil else {
            Self.logger.debug("Initialization already in progress, skipping")
            return
        }
        
        initializationTask = Task {
            await initialize()
        }
    }
    
    /// Executes both initialisation phases sequentially, publishing `state` updates throughout.
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
    
    /// Polls `state` every 50 ms until the ingredients phase completes or a failure occurs.
    func waitForIngredients() async {
        while !state.isIngredientsReady {
            if case .failed = state {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
    
    /// Polls `state` every 50 ms until the full sequence completes or a failure occurs.
    func waitForRecipes() async {
        while !state.isRecipesReady {
            if case .failed = state {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    #if DEBUG
    /// Cancels any in-progress initialisation task and forces state to `.ready`.
    /// Used by unit tests to bypass real data loading without running CSV imports.
    func markReadyForTesting() {
        initializationTask?.cancel()
        initializationTask = nil
        state = .ready
    }
    #endif
}
