//
//  DBInterfaceProtocol.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import Foundation

// MARK: - Database Error Types

/// Structured errors surfaced by the database layer.
///
/// Each case carries enough context to diagnose the failure — the affected record name,
/// a description of the failing query, or the underlying system error.
enum DatabaseError: Error, LocalizedError {
    /// A recipe lookup failed because no recipe with the given title exists in the database.
    case recipeNotFound(String)
    /// An ingredient lookup failed because no ingredient with the given name exists in the database.
    case ingredientNotFound(String)
    /// A SQL query failed unexpectedly. Includes a human-readable query description and the underlying GRDB error.
    case queryFailed(String, underlying: Error)
    /// An operation on the in-memory recipe cache failed.
    case cacheError(String)
    /// The database could not be initialised at startup; wraps the underlying GRDB or file-system error.
    case initializationError(Error)
    
    var errorDescription: String? {
        switch self {
        case .recipeNotFound(let title):
            return "Recipe '\(title)' not found"
        case .ingredientNotFound(let name):
            return "Ingredient '\(name)' not found"
        case .queryFailed(let query, let underlying):
            return "Database query failed: \(query). Underlying error: \(underlying.localizedDescription)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        case .initializationError(let error):
            return "Database initialization failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Domain Store Protocols
//
// The database surface is segregated into focused, domain-scoped protocols so each
// consumer can depend only on the operations it actually uses (Interface Segregation).
// The concrete `DBInterface` conforms to all of them via the composite
// `DBInterfaceProtocol` declared at the bottom of this file. All methods are `async` and
// throwing: the concrete `DBInterface` is an `actor`, so its SQL and JSON-decoding work
// runs on the actor's executor (off the main actor), and callers `await` each call.

/// Read/write access to the ingredient catalogue and full-text search.
nonisolated protocol IngredientStoreProtocol {
    /// Returns all ingredients whose name exactly matches `name` (case-insensitive).
    /// - Parameter name: The ingredient name to look up.
    /// - Returns: A single-element array if found, or an empty array if no match exists.
    func getIngredients(byName name:String) async throws -> [Ingredient]

    /// Performs an FTS5 prefix search over ingredient names.
    /// - Parameters:
    ///   - query: The search term. The implementation appends `*` for prefix matching.
    ///   - limit: Maximum number of results to return.
    /// - Returns: Ingredients ranked by FTS5 relevance.
    func searchIngredients(matching query: String, limit: Int) async throws -> [Ingredient]

    /// Inserts or replaces a batch of ingredients using `INSERT OR REPLACE`.
    /// - Parameter ingredients: The ingredients to persist.
    func insertIngredients(_ ingredients: [Ingredient]) async throws

    /// Removes the given ingredients from the database by name.
    /// - Parameter ingredients: The ingredients to delete.
    func removeIngredients(_ ingredients: [Ingredient]) async throws

    /// Returns all ingredients, optionally filtered to a specific food group, sorted alphabetically.
    /// - Parameters:
    ///   - foodGroup: Optional food group filter (e.g. `"Vegetables"`). `nil` returns all.
    ///   - limit: Maximum number of results.
    func getAllIngredients(inGroup foodGroup: String?, limit: Int) async throws -> [Ingredient]

    /// Returns all distinct non-null food group values in the `ingredients` table, sorted alphabetically.
    func getDistinctFoodGroups() async throws -> [String]
}

/// Read/write access to the recipe catalogue (seeded + user-created).
nonisolated protocol RecipeStoreProtocol {
    /// Fetches recipes that contain at least one of the given ingredients.
    /// Uses `LIKE` wildcards for partial matching (e.g., "chicken" matches "chicken breast").
    /// - Parameters:
    ///   - byIngredients: The ingredient set to search by.
    ///   - offset: Pagination offset.
    ///   - limit: Maximum number of results.
    func getRecipes(byIngredients: [Ingredient], offset: Int, limit: Int) async throws -> [Recipe]

    /// Fetches all recipes with offset pagination.
    /// - Parameters:
    ///   - offset: Pagination offset.
    ///   - limit: Maximum number of results.
    func getAllRecipes(offset: Int, limit: Int) async throws -> [Recipe]

    /// Looks up a recipe's database primary key by its title.
    /// - Parameter title: The recipe title to look up.
    /// - Returns: The integer primary key, or `nil` if not found.
    func getRecipeId(byTitle title: String) async throws -> Int?

    /// Fetches a single recipe by its primary key.
    /// - Parameter id: The recipe's database ID.
    /// - Returns: The recipe, or `nil` if not found.
    func getRecipe(byID id: Int) async throws -> Recipe?

    /// Inserts a batch of recipes and their ingredient-link rows into the database.
    /// - Parameter recipes: The recipes to persist.
    func insertRecipes(_ recipes: [Recipe]) async throws

    /// Removes the given recipes from the database by title.
    /// - Parameter recipes: The recipes to delete.
    func removeRecipes(_ recipes: [Recipe]) async throws
}

/// Tracking of recent/popular ingredients, recent recipe views, and saved searches.
nonisolated protocol RecentActivityStoreProtocol {
    /// Returns the most recently used ingredients, sorted by `last_used_at` descending.
    /// - Parameter limit: Maximum number of results.
    func getRecentIngredients(limit: Int) async throws -> [Ingredient]

    /// Returns ingredients ordered by frequency of use, with recency as a tiebreaker.
    /// - Parameter limit: Maximum number of results.
    func getPopularIngredients(limit: Int) async throws -> [Ingredient]

    /// Upserts the ingredient into `recent_ingredients`, incrementing its `use_count`.
    /// Silently skips if the ingredient does not exist in the `ingredients` table.
    /// - Parameter ingredient: The ingredient that was used.
    func recordIngredientUsage(_ ingredient: Ingredient) async throws

    /// Returns the most recently viewed recipes, sorted by `last_viewed_at` descending.
    /// - Parameter limit: Maximum number of results.
    func getRecentRecipes(limit: Int) async throws -> [Recipe]

    /// Upserts a recipe view event into `recent_recipes`, incrementing its `view_count`.
    /// - Parameter recipeId: The ID of the viewed recipe.
    func recordRecipeView(_ recipeId: Int) async throws

    /// Returns the most recent ingredient-combination searches, newest first.
    /// Each element is the set of ingredients used in a single search.
    /// - Parameter limit: Maximum number of searches to return.
    func getRecentSearches(limit: Int) async throws -> [[Ingredient]]

    /// Records an ingredient search. Automatically prunes the table to the 50 most recent entries.
    /// - Parameter ingredients: The ingredient combination that was searched.
    func recordSearch(ingredients: [Ingredient]) async throws
}

/// Read/write access to the user's favourited recipes.
nonisolated protocol FavoritesStoreProtocol {
    /// Returns all favorited recipes, sorted by `added_at` descending.
    func getFavoriteRecipes() async throws -> [Recipe]

    /// Adds a recipe to favourites using `INSERT OR IGNORE` so duplicate calls are safe.
    /// - Parameter recipeId: The ID of the recipe to favourite.
    func addFavorite(_ recipeId: Int) async throws

    /// Removes a recipe from favourites.
    /// - Parameter recipeId: The ID of the recipe to unfavourite.
    func removeFavorite(_ recipeId: Int) async throws

    /// Returns whether a recipe is currently in the user's favourites.
    /// - Parameter recipeId: The ID of the recipe to check.
    func isFavorite(_ recipeId: Int) async throws -> Bool
}

/// Recording and aggregate querying of cook-mode completion sessions.
nonisolated protocol CookingSessionStoreProtocol {
    /// Records a completed cooking session without rescued-ingredient data.
    /// Delegates to the full variant with `rescuedIngredients: nil`.
    func recordCookingSession(recipeId: Int, date: Date, duration: TimeInterval?, rating: Int?) async throws

    /// Records a completed cooking session, optionally including which ingredients were actually used.
    ///
    /// When `rescuedIngredients` is provided, those names are stored as JSON and override the
    /// recipe's default ingredient list when computing "distinct cooked ingredients" statistics.
    /// - Parameters:
    ///   - recipeId: The recipe that was cooked.
    ///   - date: When the session occurred.
    ///   - duration: How long the session lasted.
    ///   - rating: Optional star rating (1–5).
    ///   - rescuedIngredients: Ingredient names to record instead of the recipe's default list.
    func recordCookingSession(recipeId: Int, date: Date, duration: TimeInterval?, rating: Int?, rescuedIngredients: [String]?) async throws

    /// Returns recent cooking sessions joined with recipe titles.
    /// - Parameter limit: Maximum number of sessions to return.
    func getCookingSessions(limit: Int) async throws -> [CookingSession]

    /// Returns the timestamps of all cooking sessions within an inclusive date range.
    /// - Parameters:
    ///   - startDate: Range start (inclusive).
    ///   - endDate: Range end (inclusive).
    func getCookingSessionDates(from startDate: Date, to endDate: Date) async throws -> [Date]

    /// Returns the total number of recorded cooking sessions.
    func getCookingSessionCount() async throws -> Int

    /// Returns the cumulative duration of all cooking sessions in seconds.
    func getTotalCookingDuration() async throws -> TimeInterval

    /// Returns the number of cooking sessions within a half-open date range `[startDate, endDate)`.
    func getCookingSessionCount(from startDate: Date, to endDate: Date) async throws -> Int

    /// Returns the count of distinct ingredients cooked within a date range.
    ///
    /// Uses a `UNION` query: sessions with `ingredients_rescued_json` expand that JSON array;
    /// sessions without it join `recipe_ingredients` for the recipe's default ingredient list.
    func getDistinctCookedIngredientCount(from startDate: Date, to endDate: Date) async throws -> Int

    /// Returns the count of distinct ingredients that appear across all cooking sessions (all time).
    ///
    /// Uses the same `UNION` logic as the date-ranged variant: sessions with
    /// `ingredients_rescued_json` use those names; sessions without use `recipe_ingredients`.
    func getDistinctCookedIngredientCount() async throws -> Int
}

/// CRUD for recipes authored by the user (`is_user_created = 1`).
nonisolated protocol UserRecipeStoreProtocol {
    /// Returns all user-created recipes (`is_user_created = 1`), newest first.
    func getUserCreatedRecipes() async throws -> [Recipe]

    /// Returns the count of user-created recipes.
    func getUserCreatedRecipeCount() async throws -> Int

    /// Sets `isUserCreated = true` on `recipe` and inserts it into the database.
    func insertUserRecipe(_ recipe: Recipe) async throws

    /// Updates all fields of a user-created recipe and rebuilds its ingredient links.
    /// - Throws: `DatabaseError.recipeNotFound` if no matching recipe exists.
    func updateUserRecipe(_ recipe: Recipe) async throws

    /// Deletes a user-created recipe. The `is_user_created = 1` guard prevents accidental
    /// deletion of seeded recipes.
    func deleteUserRecipe(recipeId: Int) async throws
}

/// Read/write access to the free-tier pantry staples.
nonisolated protocol PantryStoreProtocol {
    /// Returns pantry staples sorted by the time they were added, newest first.
    func getPantryItems() async throws -> [Ingredient]

    /// Adds an ingredient to the user's pantry staples.
    ///
    /// The concrete database implementation resolves the canonical ingredient row
    /// before inserting, so repeated calls with different casing remain idempotent.
    func addPantryItem(_ ingredient: Ingredient) async throws

    /// Removes an ingredient from the user's pantry staples.
    func removePantryItem(_ ingredient: Ingredient) async throws

    /// Returns whether an ingredient is currently marked as a pantry staple.
    func isPantryItem(_ ingredient: Ingredient) async throws -> Bool
}

/// CRUD for the premium shopping list.
nonisolated protocol ShoppingListStoreProtocol {
    /// Returns all shopping list items ordered by `added_at` ascending.
    func getShoppingItems() async throws -> [ShoppingItem]

    /// Inserts multiple shopping items and returns the persisted records with generated IDs.
    /// - Parameters:
    ///   - names: Ingredient names to add to the list.
    ///   - recipeTitle: Optional recipe the items are associated with.
    func addShoppingItems(_ names: [String], recipeTitle: String?) async throws -> [ShoppingItem]

    /// Atomically toggles the `is_checked` state of a shopping item.
    /// - Returns: `true` if the item is now checked, `false` if now unchecked.
    func toggleShoppingItem(id: Int) async throws -> Bool

    /// Deletes a shopping item by its primary key.
    func removeShoppingItem(id: Int) async throws

    /// Deletes all shopping items that are currently checked.
    func clearCheckedShoppingItems() async throws
}

/// Aggregate catalogue statistics.
nonisolated protocol StatisticsStoreProtocol {
    /// Returns the total number of recipes in the database (seeded + user-created).
    func getRecipeCount() async throws -> Int
}

/// Bulk-clearing operations used for reset/sign-out flows.
nonisolated protocol DatabaseMaintenanceProtocol {
    /// Deletes all rows from every table, returning the database to an empty state.
    func clearDatabase() async throws

    /// Deletes recent searches, recent recipe views, and recent ingredient usage.
    func clearRecentData() async throws

    /// Deletes all entries from the `favorite_recipes` table.
    func clearFavorites() async throws
}

// MARK: - Composite Protocol

/// The primary database access abstraction for CookSavvy.
///
/// A composite of the focused domain store protocols above, covering the full set of
/// domain objects: ingredients, recipes, recent history, favourites, saved searches,
/// cooking sessions, user-created recipes, shopping list items, and aggregate statistics.
/// Broad facades (`UserDataService`, `AppContainer`, DEBUG seeding) depend on this composite;
/// focused consumers depend on the narrow protocol(s) they actually use.
///
/// All methods are `async` and throwing. The concrete implementation is `DBInterface`, an
/// `actor` backed by GRDB's `DatabaseWriter`; SQL and JSON decoding run on the actor's
/// executor (off the main actor) and callers `await` each call. An in-memory variant is
/// available for unit tests via `DBInterface(inMemory: true)`.
nonisolated protocol DBInterfaceProtocol:
    IngredientStoreProtocol,
    RecipeStoreProtocol,
    RecentActivityStoreProtocol,
    FavoritesStoreProtocol,
    CookingSessionStoreProtocol,
    UserRecipeStoreProtocol,
    PantryStoreProtocol,
    ShoppingListStoreProtocol,
    StatisticsStoreProtocol,
    DatabaseMaintenanceProtocol {}
