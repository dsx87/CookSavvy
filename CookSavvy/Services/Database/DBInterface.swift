//
//  DBInterface.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import Foundation
import GRDB
import os.log

// MARK: - GRDB-backed implementation

/// GRDB-backed concrete implementation of `DBInterfaceProtocol`.
///
/// Manages a single SQLite database containing the app's persisted tables:
/// - `ingredients` / `ingredients_fts` — ingredient catalogue with FTS5 full-text search
/// - `recipes` / `recipes_fts` — recipe catalogue with FTS5 search on title
/// - `recipe_ingredients` — many-to-many link table (recipe ↔ ingredient name)
/// - `recent_ingredients` — per-ingredient usage frequency and recency
/// - `recent_recipes` — per-recipe view count and recency
/// - `favorite_recipes` — user-bookmarked recipes
/// - `recent_searches` — stored ingredient-combination searches (capped at 50 entries)
/// - `pantry_items` — free-tier staple ingredients that are always treated as available
/// - `cooking_sessions` — timestamped cook-mode completions with optional duration, rating, and rescued-ingredient list
/// - `shopping_items` — premium shopping list entries
///
/// **Thread safety**: file-based databases use a `DatabasePool` (concurrent reads, serialised writes);
/// the in-memory test variant uses a `DatabaseQueue`. GRDB serialises all write access automatically.
///
/// **JSON columns**: `instructions_json`, `ingredients_json`, and `additional_info_json` in `recipes`
/// store model objects as JSON blobs to avoid schema churn as models evolve.
/// The `cleaned_ingredients_json` column still exists in the schema for backward compatibility but
/// is no longer read or meaningfully written (always stored as `'[]'`).
///
/// **Recipe cache**: a title-keyed in-memory dictionary (`maxRecipeCacheSize = 100`) reduces
/// repeated JSON decoding for hot recipes. Eviction is simple FIFO.
///
/// **Dates**: all timestamps are stored as Unix epoch integers (seconds since 1970).
///
/// **Schema migrations**: `createSchema()` applies lightweight `ALTER TABLE` migrations inline
/// using a `db.columns(in:).contains(…)` guard. New migrations should follow the same pattern.
final class DBInterface: DBInterfaceProtocol {
    // MARK: - DB
    /// GRDB writer providing thread-safe reads and serialised writes.
    /// `DatabasePool` for file-based databases; `DatabaseQueue` for in-memory test databases.
    private let dbWriter: DatabaseWriter

    // MARK: - JSON coders
    /// Shared encoder used when serialising recipe model objects to JSON columns.
    private let encoder = JSONEncoder()
    /// Shared decoder used when deserialising recipe model objects from JSON columns.
    private let decoder = JSONDecoder()
    
    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "Database"
    )

    // MARK: - Test helpers (only used in test mode)
    /// Non-nil only when the instance was created with `inMemory: true`.
    /// Wires deterministic ingredient-variant delivery into `getIngredients(byName:)`.
    private let testHelpers: DBTestHelpers?
    
    // MARK: - Recipe caching
    /// In-memory title-keyed recipe cache to avoid repeated JSON decoding for hot recipes.
    private var recipeCache: [String: Recipe] = [:]
    /// Serialises all access to `recipeCache` for thread safety.
    private let cacheQueue = DispatchQueue(label: "com.cooksavvy.database.recipe-cache")
    /// Maximum number of recipes held in `recipeCache`. Eviction is simple FIFO.
    private let maxRecipeCacheSize = 100

    /// Shared `SELECT` column list used in every recipe query, aliased under `r`.
    /// Keeping this in one place ensures all queries produce the row shape that `decodeRecipe(from:)` expects.
    private static let recipeColumns = "r.id, r.title, r.image, r.instructions_json, r.ingredients_json, r.additional_info_json, r.source, r.tagline, r.user_rating, r.api_rating, r.author, r.is_user_created, r.emoji, r.cuisine"

    // MARK: - Init
    /// Creates a file-based database in the app's Application Support directory (`CookSavvy/db.sqlite`).
    /// - Throws: A `DatabaseError.initializationError` if the directory cannot be created or schema setup fails.
    convenience init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("CookSavvy", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
        try self.init(databaseURL: databaseURL)
    }
    
    /// Creates an in-memory database for unit tests when `inMemory` is `true`.
    ///
    /// The in-memory database uses a `DatabaseQueue` (not `DatabasePool`) and attaches a
    /// `DBTestHelpers` instance for deterministic ingredient variant delivery. Passing `false`
    /// falls through to the default file-based initialiser.
    /// - Parameter inMemory: Pass `true` to force an in-memory SQLite database.
    convenience init(inMemory: Bool) throws {
        guard inMemory else {
            try self.init()
            return
        }

        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
        }
        let writer = try DatabaseQueue(path: ":memory:", configuration: configuration)
        try self.init(dbWriter: writer, testHelpers: DBTestHelpers())
    }

    /// Creates a file-based database at a specific URL using a `DatabasePool`.
    /// - Parameter databaseURL: File URL for the `.sqlite` database file.
    convenience init(databaseURL: URL) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
        }
        let writer = try DatabasePool(path: databaseURL.path, configuration: configuration)
        try self.init(dbWriter: writer, testHelpers: nil)
    }

    /// Designated initialiser: stores the writer, attaches test helpers, and creates the schema.
    /// - Parameters:
    ///   - dbWriter: A pre-configured GRDB writer (pool or queue).
    ///   - testHelpers: Optional test-variant helper; non-nil only in in-memory mode.
    private init(dbWriter: DatabaseWriter, testHelpers: DBTestHelpers?) throws {
        self.dbWriter = dbWriter
        self.testHelpers = testHelpers
        do {
            try createSchema()
        } catch {
            Self.logger.error("Database schema creation failed: \(error.localizedDescription)")
            throw DatabaseError.initializationError(error)
        }
    }

    // MARK: - Schema
    /// Creates all database tables, FTS virtual tables, triggers, indexes, and inline migrations.
    ///
    /// All `CREATE TABLE` / `CREATE VIRTUAL TABLE` / `CREATE TRIGGER` / `CREATE INDEX` statements
    /// use `IF NOT EXISTS`, making the method safe to call on every app launch.
    ///
    /// **FTS setup** (ingredients and recipes): each main table has a paired `_fts` virtual table
    /// using FTS5 with `content=` pointing at the main table. Three triggers per table
    /// (`_ai`, `_ad`, `_au`) keep the FTS index in sync with inserts, deletes, and updates.
    ///
    /// **Inline migration**: after creating `cooking_sessions`, the method checks whether the
    /// `ingredients_rescued_json` column exists and runs `ALTER TABLE … ADD COLUMN` if absent.
    /// This pattern allows lightweight schema evolution without a separate migration framework.
    private func createSchema() throws {
        try dbWriter.write { db in
            // 1. Ingredients
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS ingredients (
                    name TEXT PRIMARY KEY,
                    description TEXT,
                    picture_file_name TEXT,
                    food_group TEXT,
                    food_subgroup TEXT
                );
                """)
            
            // FTS for Ingredients
            // We use an external content FTS table to save space and keep 'ingredients' as the source of truth
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS ingredients_fts USING fts5(
                    name,
                    content='ingredients',
                    content_rowid='rowid'
                );
                """)
            
            // Triggers to keep ingredients_fts in sync
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS ingredients_ai AFTER INSERT ON ingredients BEGIN
                    INSERT INTO ingredients_fts(rowid, name) VALUES (new.rowid, new.name);
                END;
                CREATE TRIGGER IF NOT EXISTS ingredients_ad AFTER DELETE ON ingredients BEGIN
                    INSERT INTO ingredients_fts(ingredients_fts, rowid, name) VALUES('delete', old.rowid, old.name);
                END;
                CREATE TRIGGER IF NOT EXISTS ingredients_au AFTER UPDATE ON ingredients BEGIN
                    INSERT INTO ingredients_fts(ingredients_fts, rowid, name) VALUES('delete', old.rowid, old.name);
                    INSERT INTO ingredients_fts(rowid, name) VALUES (new.rowid, new.name);
                END;
                """)

            // 2. Recipes
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recipes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL,
                    image TEXT NOT NULL,
                    instructions_json TEXT NOT NULL,
                    ingredients_json TEXT NOT NULL,
                    cleaned_ingredients_json TEXT NOT NULL,
                    additional_info_json TEXT NOT NULL,
                    source TEXT,
                    tagline TEXT,
                    user_rating REAL,
                    api_rating REAL,
                    author TEXT,
                    is_user_created INTEGER DEFAULT 0,
                    emoji TEXT,
                    cuisine TEXT
                );
                """)
            
            // FTS for Recipes (indexing title and maybe ingredients content if needed, but title is most important for now)
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS recipes_fts USING fts5(
                    title,
                    content='recipes',
                    content_rowid='id'
                );
                """)
            
            // Triggers for recipes_fts
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS recipes_ai AFTER INSERT ON recipes BEGIN
                    INSERT INTO recipes_fts(rowid, title) VALUES (new.id, new.title);
                END;
                CREATE TRIGGER IF NOT EXISTS recipes_ad AFTER DELETE ON recipes BEGIN
                    INSERT INTO recipes_fts(recipes_fts, rowid, title) VALUES('delete', old.id, old.title);
                END;
                CREATE TRIGGER IF NOT EXISTS recipes_au AFTER UPDATE ON recipes BEGIN
                    INSERT INTO recipes_fts(recipes_fts, rowid, title) VALUES('delete', old.id, old.title);
                    INSERT INTO recipes_fts(rowid, title) VALUES (new.id, new.title);
                END;
                """)

            // 3. Recipe Ingredients Link
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recipe_ingredients (
                    recipe_id INTEGER NOT NULL,
                    ingredient_name TEXT NOT NULL,
                    FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
                );
                """)

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_name ON recipe_ingredients(ingredient_name);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recipes_title ON recipes(title);")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_composite ON recipe_ingredients(recipe_id, ingredient_name);")

            // 4. Recent Ingredients (for quick selection)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recent_ingredients (
                    ingredient_name TEXT PRIMARY KEY,
                    last_used_at INTEGER NOT NULL,
                    use_count INTEGER DEFAULT 1,
                    FOREIGN KEY(ingredient_name) REFERENCES ingredients(name) ON DELETE CASCADE
                );
                """)

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recent_ingredients_last_used ON recent_ingredients(last_used_at DESC);")

            // 5. Recent Recipe Views
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recent_recipes (
                    recipe_id INTEGER PRIMARY KEY,
                    last_viewed_at INTEGER NOT NULL,
                    view_count INTEGER DEFAULT 1,
                    FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
                );
                """)

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recent_recipes_last_viewed ON recent_recipes(last_viewed_at DESC);")

            // 6. Favorite Recipes
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS favorite_recipes (
                    recipe_id INTEGER PRIMARY KEY,
                    added_at INTEGER NOT NULL,
                    FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
                );
                """)

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_favorite_recipes_added ON favorite_recipes(added_at DESC);")

            // 7. Recent Searches (ingredient combinations)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS recent_searches (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    search_date INTEGER NOT NULL,
                    ingredient_names_json TEXT NOT NULL
                );
                """)

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_recent_searches_date ON recent_searches(search_date DESC);")

            // 8. Pantry Items
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS pantry_items (
                    ingredient_name TEXT PRIMARY KEY,
                    added_at INTEGER NOT NULL,
                    FOREIGN KEY(ingredient_name) REFERENCES ingredients(name) ON DELETE CASCADE
                );
                """)

            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_pantry_items_added ON pantry_items(added_at DESC);")

            // 9. Cooking Sessions
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS cooking_sessions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    recipe_id INTEGER NOT NULL,
                    cooked_at INTEGER NOT NULL,
                    duration_seconds INTEGER,
                    rating INTEGER,
                    FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
                );
                """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_cooking_sessions_date ON cooking_sessions(cooked_at DESC);")

            // Migration: add ingredients_rescued_json column if not present
            let cookingColumns = try db.columns(in: "cooking_sessions").map { $0.name }
            if !cookingColumns.contains("ingredients_rescued_json") {
                try db.execute(sql: "ALTER TABLE cooking_sessions ADD COLUMN ingredients_rescued_json TEXT;")
            }

            // 10. Shopping List
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS shopping_items (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT NOT NULL,
                    is_checked INTEGER DEFAULT 0,
                    added_at INTEGER NOT NULL,
                    recipe_title TEXT
                );
                """)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_shopping_items_added ON shopping_items(added_at DESC);")
        }
    }

    // MARK: - DBInterfaceProtocol
    /// Returns all ingredients whose name exactly matches `name` (case-insensitive `COLLATE NOCASE`).
    ///
    /// In test mode, delegates to `DBTestHelpers.getNextVariant(for:)` first, allowing unit tests
    /// to control returned values without touching the real database rows.
    /// - Parameter name: The exact ingredient name to look up.
    /// - Returns: A single-element array if found, or an empty array if not.
    func getIngredients(byName name: String) throws -> [Ingredient] {
        // Use test helpers for variant tracking if available (test mode)
        if let testHelpers = testHelpers,
           let variant = testHelpers.getNextVariant(for: name) {
            return [variant]
        }

        // Regular DB lookup
        return try dbWriter.read { db in
            if let row = try Row.fetchOne(db, sql: "SELECT name, description, picture_file_name, food_group, food_subgroup FROM ingredients WHERE name = ? COLLATE NOCASE;", arguments: [name]) {
                let ingredient = Ingredient(
                    name: row["name"],
                    description: row["description"],
                    pictureFileName: row["picture_file_name"],
                    foodGroup: row["food_group"],
                    foodSubgroup: row["food_subgroup"]
                )
                return [ingredient]
            } else {
                return []
            }
        }
    }

    /// Searches ingredients using FTS5 prefix matching.
    ///
    /// The query is sanitised (double-quotes stripped) then wrapped in the FTS5 phrase-prefix
    /// syntax `"<query>"*` so "chick" matches "Chicken", "Chicken Breast", etc. Results are
    /// joined with the main `ingredients` table to retrieve full metadata and ordered by FTS5 rank.
    /// - Parameters:
    ///   - query: The user-entered search string. Empty queries return immediately with no results.
    ///   - limit: Maximum number of results (default 50).
    func searchIngredients(matching query: String, limit: Int = 50) throws -> [Ingredient] {
        guard !query.isEmpty else { return [] }
        
        // Use FTS5 for efficient prefix search
        // We want "chick*" to match "Chicken", "Chicken Breast", etc.
        // Sanitize query to avoid FTS syntax errors if user types special chars
        let sanitized = query.replacingOccurrences(of: "\"", with: "")
        let pattern = "\"\(sanitized)\"*" // Prefix search
        
        return try dbWriter.read { db in
            // Join with the main table to get full details
            let sql = """
                SELECT i.name, i.description, i.picture_file_name, i.food_group, i.food_subgroup
                FROM ingredients i
                JOIN ingredients_fts fts ON fts.rowid = i.rowid
                WHERE ingredients_fts MATCH ?
                ORDER BY rank
                LIMIT ?;
            """
            return try Row.fetchAll(db, sql: sql, arguments: [pattern, limit]).map { row in
                Ingredient(
                    name: row["name"],
                    description: row["description"],
                    pictureFileName: row["picture_file_name"],
                    foodGroup: row["food_group"],
                    foodSubgroup: row["food_subgroup"]
                )
            }
        }
    }

    /// Fetches paginated recipes that contain at least one of the specified ingredients.
    ///
    /// Uses `LIKE '%name%'` wildcards rather than exact joins so that "chicken" also matches
    /// recipe ingredients listed as "chicken breast" or "grilled chicken". This trades some
    /// precision for recall — scoring and ranking layers above this method handle deduplication.
    ///
    /// Hot results are served from the title-keyed `recipeCache` to avoid repeated JSON decoding.
    /// - Parameters:
    ///   - ingredients: The ingredient set to search by (empty set returns immediately).
    ///   - offset: Pagination offset.
    ///   - limit: Maximum number of results (default 20).
    func getRecipes(byIngredients ingredients: [Ingredient], offset: Int = 0, limit: Int = 20) throws -> [Recipe] {
        let ingredientNames = Set(ingredients.map { $0.name })
        if ingredientNames.isEmpty { return [] }
        
        Self.logger.debug("Searching recipes for ingredients: \(ingredientNames.joined(separator: ", ")) [offset: \(offset), limit: \(limit)]")
        
        // Build LIKE conditions for partial matching to handle cases like "chicken" matching "chicken breast"
        let likeConditions = ingredientNames.map { _ in "LOWER(ri.ingredient_name) LIKE LOWER(?)" }.joined(separator: " OR ")
        let likeValues = ingredientNames.map { "%\($0)%" } // Add wildcards for partial matching
        
        let sql = """
            SELECT DISTINCT \(Self.recipeColumns)
            FROM recipes r
            INNER JOIN recipe_ingredients ri ON ri.recipe_id = r.id
            WHERE \(likeConditions)
            ORDER BY r.id ASC
            LIMIT ? OFFSET ?;
        """
        
        var arguments: [DatabaseValueConvertible] = likeValues
        arguments.append(limit)
        arguments.append(offset)
        
        let rows: [Row] = try dbWriter.read { db in
            try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
        }

        var results: [Recipe] = []
        results.reserveCapacity(rows.count)
        for row in rows {
            let title: String = row["title"]
            
            if let cachedRecipe = cachedRecipe(forTitle: title) {
                results.append(cachedRecipe)
                continue
            }
            
            let recipe = try decodeRecipe(from: row)
            cacheRecipe(recipe)
            results.append(recipe)
        }
        
        Self.logger.info("Found \(results.count) recipes for \(ingredientNames.count) ingredients")
        return results
    }
    
    /// Fetches all recipes with offset pagination. Results are served from `recipeCache` where available.
    func getAllRecipes(offset: Int = 0, limit: Int = 50) throws -> [Recipe] {
        let sql = """
            SELECT \(Self.recipeColumns)
            FROM recipes r
            ORDER BY r.id ASC
            LIMIT ? OFFSET ?;
        """
        let rows: [Row] = try dbWriter.read { db in
            try Row.fetchAll(db, sql: sql, arguments: [limit, offset])
        }
        var results: [Recipe] = []
        results.reserveCapacity(rows.count)
        for row in rows {
            results.append(try cachedRecipe(from: row))
        }
        return results
    }

    /// Fetches a single recipe by its primary key.
    /// - Parameter id: The recipe's integer primary key.
    /// - Returns: The decoded recipe if found, `nil` otherwise.
    func getRecipe(byID id: Int) throws -> Recipe? {
        let sql = """
            SELECT \(Self.recipeColumns)
            FROM recipes r
            WHERE r.id = ?
            LIMIT 1;
        """
        guard let row: Row = try dbWriter.read({ db in
            try Row.fetchOne(db, sql: sql, arguments: [id])
        }) else {
            return nil
        }
        return try cachedRecipe(from: row)
    }

    // MARK: - Private Recipe Caching Methods

    /// Returns a cached recipe for the given row, or decodes and caches it on first access.
    private func cachedRecipe(from row: Row) throws -> Recipe {
        let title: String = row["title"]
        if let cachedRecipe = cachedRecipe(forTitle: title) {
            return cachedRecipe
        }

        let recipe = try decodeRecipe(from: row)
        cacheRecipe(recipe)
        return recipe
    }
    
    /// Stores a recipe in the cache, evicting the oldest entry (FIFO) when the limit is reached.
    private func cacheRecipe(_ recipe: Recipe) {
        cacheQueue.sync {
            // Enforce cache size limit with simple FIFO
            if recipeCache.count >= maxRecipeCacheSize {
                if let firstKey = recipeCache.keys.first {
                    recipeCache.removeValue(forKey: firstKey)
                }
            }
            recipeCache[recipe.title] = recipe
        }
    }

    /// Thread-safe read from `recipeCache` keyed by recipe title.
    private func cachedRecipe(forTitle title: String) -> Recipe? {
        cacheQueue.sync { recipeCache[title] }
    }

    /// Removes all entries from `recipeCache`.
    private func clearRecipeCache() {
        cacheQueue.sync {
            recipeCache.removeAll()
        }
    }

    /// Removes a single recipe from `recipeCache` by title; called after update and delete operations.
    private func removeCachedRecipe(forTitle title: String) {
        cacheQueue.sync {
            _ = recipeCache.removeValue(forKey: title)
        }
    }

    /// Inserts or replaces a batch of ingredients using `INSERT OR REPLACE`.
    /// In test mode, also registers each ingredient with `DBTestHelpers` for variant tracking.
    func insertIngredients(_ ingredients: [Ingredient]) throws {
        guard !ingredients.isEmpty else { return }
        try dbWriter.write { db in
            for ing in ingredients {
                // Add to test helpers for variant tracking if available (test mode)
                testHelpers?.addIngredientVariants([ing])

                try db.execute(
                    sql: "INSERT OR REPLACE INTO ingredients(name, description, picture_file_name, food_group, food_subgroup) VALUES (?, ?, ?, ?, ?);",
                    arguments: [
                        ing.name,
                        ing.description,
                        ing.pictureFileName,
                        ing.foodGroup,
                        ing.foodSubgroup
                    ]
                )
            }
        }
    }

    /// Inserts a batch of recipes and their `recipe_ingredients` link rows in a single write transaction.
    ///
    /// Complex fields (`instructions`, `ingredients`, `additionalInfo`) are
    /// JSON-encoded before storage. Duplicate ingredient names within a single recipe are
    /// deduplicated before inserting into `recipe_ingredients` — some dataset recipes list
    /// the same ingredient more than once.
    func insertRecipes(_ recipes: [Recipe]) throws {
        guard !recipes.isEmpty else { return }
        try dbWriter.write { db in
            for r in recipes {
                let instructionsJSON = try String(data: encoder.encode(r.instructions), encoding: .utf8) ?? "[]"
                let ingredientsJSON = try String(data: encoder.encode(r.ingredients), encoding: .utf8) ?? "[]"
                let additionalJSON = try String(data: encoder.encode(r.additionalInfo), encoding: .utf8) ?? "{}"

                try db.execute(
                    sql: "INSERT INTO recipes(title, image, instructions_json, ingredients_json, cleaned_ingredients_json, additional_info_json, source, tagline, user_rating, api_rating, author, is_user_created, emoji, cuisine) VALUES (?, ?, ?, ?, '[]', ?, ?, ?, ?, ?, ?, ?, ?, ?);",
                    arguments: [r.title, r.image, instructionsJSON, ingredientsJSON, additionalJSON, r.source?.rawValue, r.tagline, r.userRating, r.apiRating, r.author, r.isUserCreated ? 1 : 0, r.emoji, r.cuisine]
                )

                let recipeId = db.lastInsertedRowID

                // Link unique ingredient names for querying
                var seen: Set<String> = []
                for ing in r.ingredients {
                    let name = ing.name
                    if seen.contains(name) { continue }
                    seen.insert(name)
                    try db.execute(
                        sql: "INSERT INTO recipe_ingredients(recipe_id, ingredient_name) VALUES(?, ?);",
                        arguments: [recipeId, name]
                    )
                }
            }
        }
    }

    /// Removes the given ingredients by extracting their names and delegating to `removeIngredients(_:)`.
    func removeIngredients(_ ingredients: [Ingredient]) throws {
        try removeIngredients(ingredients.map { $0.name })
    }

    /// Removes the given recipes by extracting their titles and delegating to `removeRecipes(withTitles:)`.
    func removeRecipes(_ recipes: [Recipe]) throws {
        let titles = recipes.map { $0.title }
        try removeRecipes(withTitles: titles)
    }

    /// Deletes all rows from every table, and clears the in-memory recipe cache and test variants.
    func clearDatabase() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recent_searches;")
            try db.execute(sql: "DELETE FROM pantry_items;")
            try db.execute(sql: "DELETE FROM cooking_sessions;")
            try db.execute(sql: "DELETE FROM favorite_recipes;")
            try db.execute(sql: "DELETE FROM recent_recipes;")
            try db.execute(sql: "DELETE FROM recent_ingredients;")
            try db.execute(sql: "DELETE FROM recipe_ingredients;")
            try db.execute(sql: "DELETE FROM recipes;")
            try db.execute(sql: "DELETE FROM shopping_items;")
            try db.execute(sql: "DELETE FROM ingredients;")

        }
        testHelpers?.clearVariants()
        clearRecipeCache()
    }

    /// Clears recent search history, recent recipe views, and recent ingredient usage.
    func clearRecentData() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recent_searches;")
            try db.execute(sql: "DELETE FROM recent_recipes;")
            try db.execute(sql: "DELETE FROM recent_ingredients;")
        }
    }

    /// Deletes all entries from the `favorite_recipes` table.
    func clearFavorites() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM favorite_recipes;")
        }
    }

    // MARK: - Recent Ingredients

    /// Returns the most recently used ingredients by joining `recent_ingredients` with `ingredients`,
    /// sorted by `last_used_at` descending.
    func getRecentIngredients(limit: Int) throws -> [Ingredient] {
        return try dbWriter.read { db in
            let sql = """
                SELECT i.name, i.description, i.picture_file_name, i.food_group, i.food_subgroup
                FROM recent_ingredients ri
                INNER JOIN ingredients i ON i.name = ri.ingredient_name
                ORDER BY ri.last_used_at DESC
                LIMIT ?;
            """
            return try Row.fetchAll(db, sql: sql, arguments: [limit]).map { row in
                Ingredient(
                    name: row["name"],
                    description: row["description"],
                    pictureFileName: row["picture_file_name"],
                    foodGroup: row["food_group"],
                    foodSubgroup: row["food_subgroup"]
                )
            }
        }
    }

    /// Returns the most frequently used ingredients, with recency as a tiebreaker.
    /// Sorted by `use_count` descending, then `last_used_at` descending.
    func getPopularIngredients(limit: Int) throws -> [Ingredient] {
        return try dbWriter.read { db in
            let sql = """
                SELECT i.name, i.description, i.picture_file_name, i.food_group, i.food_subgroup
                FROM recent_ingredients ri
                INNER JOIN ingredients i ON i.name = ri.ingredient_name
                ORDER BY ri.use_count DESC, ri.last_used_at DESC
                LIMIT ?;
            """
            return try Row.fetchAll(db, sql: sql, arguments: [limit]).map { row in
                Ingredient(
                    name: row["name"],
                    description: row["description"],
                    pictureFileName: row["picture_file_name"],
                    foodGroup: row["food_group"],
                    foodSubgroup: row["food_subgroup"]
                )
            }
        }
    }

    /// Upserts the ingredient into `recent_ingredients`, incrementing its `use_count`.
    ///
    /// A case-insensitive lookup resolves the canonical stored name before upserting, ensuring
    /// "Chicken" and "chicken" both map to the same `recent_ingredients` row.
    /// Silently skips if the ingredient does not exist in the `ingredients` table.
    func recordIngredientUsage(_ ingredient: Ingredient) throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        try dbWriter.write { db in
            // First check if the ingredient exists in the ingredients table
            // Use case-insensitive lookup to get the actual stored name
            let existingName: String? = try String.fetchOne(
                db,
                sql: "SELECT name FROM ingredients WHERE name = ? COLLATE NOCASE LIMIT 1;",
                arguments: [ingredient.name]
            )
            
            // Only record if the ingredient exists in the database
            guard let actualName = existingName else {
                Self.logger.warning("Ingredient '\(ingredient.name)' not found in database, skipping usage recording")
                return
            }
            
            // Insert or update recent ingredient using the actual stored name
            let sql = """
                INSERT INTO recent_ingredients (ingredient_name, last_used_at, use_count)
                VALUES (?, ?, 1)
                ON CONFLICT(ingredient_name) DO UPDATE SET
                    last_used_at = excluded.last_used_at,
                    use_count = use_count + 1;
            """
            try db.execute(sql: sql, arguments: [actualName, timestamp])
        }
    }

    // MARK: - Recent Recipes

    /// Returns recently viewed recipes joined with their full data, sorted by `last_viewed_at` descending.
    func getRecentRecipes(limit: Int) throws -> [Recipe] {
        return try dbWriter.read { db in
            let sql = """
                SELECT \(Self.recipeColumns)
                FROM recent_recipes rr
                INNER JOIN recipes r ON r.id = rr.recipe_id
                ORDER BY rr.last_viewed_at DESC
                LIMIT ?;
            """
            return try Row.fetchAll(db, sql: sql, arguments: [limit]).compactMap { row in
                try? decodeRecipe(from: row)
            }
        }
    }

    /// Upserts a recipe view event into `recent_recipes`, incrementing `view_count` on conflict.
    func recordRecipeView(_ recipeId: Int) throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        try dbWriter.write { db in
            let sql = """
                INSERT INTO recent_recipes (recipe_id, last_viewed_at, view_count)
                VALUES (?, ?, 1)
                ON CONFLICT(recipe_id) DO UPDATE SET
                    last_viewed_at = excluded.last_viewed_at,
                    view_count = view_count + 1;
            """
            try db.execute(sql: sql, arguments: [recipeId, timestamp])
        }
    }

    // MARK: - Favorites

    /// Returns all favorited recipes sorted by `added_at` descending.
    func getFavoriteRecipes() throws -> [Recipe] {
        return try dbWriter.read { db in
            let sql = """
                SELECT \(Self.recipeColumns)
                FROM favorite_recipes fr
                INNER JOIN recipes r ON r.id = fr.recipe_id
                ORDER BY fr.added_at DESC;
            """
            return try Row.fetchAll(db, sql: sql).compactMap { row in
                try? decodeRecipe(from: row)
            }
        }
    }

    /// Adds a recipe to favourites using `INSERT OR IGNORE` so duplicate calls are safe.
    func addFavorite(_ recipeId: Int) throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        try dbWriter.write { db in
            try db.execute(
                sql: "INSERT OR IGNORE INTO favorite_recipes (recipe_id, added_at) VALUES (?, ?);",
                arguments: [recipeId, timestamp]
            )
        }
    }

    /// Removes a recipe from favourites.
    func removeFavorite(_ recipeId: Int) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM favorite_recipes WHERE recipe_id = ?;",
                arguments: [recipeId]
            )
        }
    }

    /// Returns whether a recipe is currently in the user's favourites by counting matching rows.
    func isFavorite(_ recipeId: Int) throws -> Bool {
        return try dbWriter.read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM favorite_recipes WHERE recipe_id = ?;",
                arguments: [recipeId]
            ) ?? 0
            return count > 0
        }
    }

    // MARK: - Recent Searches

    /// Returns recent ingredient-combination searches, deserialising each row's JSON ingredient-name array.
    func getRecentSearches(limit: Int) throws -> [[Ingredient]] {
        return try dbWriter.read { db in
            let sql = """
                SELECT ingredient_names_json
                FROM recent_searches
                ORDER BY search_date DESC
                LIMIT ?;
            """
            return try Row.fetchAll(db, sql: sql, arguments: [limit]).compactMap { row in
                guard let json: String = row["ingredient_names_json"],
                      let data = json.data(using: .utf8),
                      let ingredientNames = try? decoder.decode([String].self, from: data) else {
                    return nil
                }
                return ingredientNames.map { Ingredient(name: $0) }
            }
        }
    }

    /// Records an ingredient search by serialising ingredient names to a JSON array.
    /// Automatically prunes `recent_searches` to the 50 most recent entries to bound table size.
    func recordSearch(ingredients: [Ingredient]) throws {
        guard !ingredients.isEmpty else { return }
        let timestamp = Int(Date().timeIntervalSince1970)
        let ingredientNames = ingredients.map { $0.name }
        let json = try String(data: encoder.encode(ingredientNames), encoding: .utf8) ?? "[]"

        try dbWriter.write { db in
            try db.execute(
                sql: "INSERT INTO recent_searches (search_date, ingredient_names_json) VALUES (?, ?);",
                arguments: [timestamp, json]
            )

            // Keep only the last 50 searches
            let countSQL = "SELECT COUNT(*) FROM recent_searches;"
            if let count = try Int.fetchOne(db, sql: countSQL), count > 50 {
                let deleteSQL = """
                    DELETE FROM recent_searches
                    WHERE id NOT IN (
                        SELECT id FROM recent_searches
                        ORDER BY search_date DESC
                        LIMIT 50
                    );
                """
                try db.execute(sql: deleteSQL)
            }
        }
    }

    // MARK: - Cooking Sessions

    /// Records a cooking session without rescued-ingredient data. Delegates to the full variant.
    func recordCookingSession(recipeId: Int, date: Date, duration: TimeInterval?, rating: Int?) throws {
        try recordCookingSession(recipeId: recipeId, date: date, duration: duration, rating: rating, rescuedIngredients: nil)
    }

    /// Records a cooking session, optionally capturing which ingredients were actually used.
    ///
    /// When `rescuedIngredients` is provided, the names are JSON-encoded into
    /// `ingredients_rescued_json`. This column overrides the recipe's linked `recipe_ingredients`
    /// rows when computing "distinct cooked ingredients" statistics — useful when the user
    /// substituted or omitted ingredients from the original recipe.
    func recordCookingSession(recipeId: Int, date: Date, duration: TimeInterval?, rating: Int?, rescuedIngredients: [String]?) throws {
        let timestamp = Int(date.timeIntervalSince1970)
        let durationSeconds: Int? = duration.map { Int($0) }
        let rescuedJSON: String? = rescuedIngredients.flatMap { ingredients in
            try? String(data: JSONEncoder().encode(ingredients), encoding: .utf8)
        }
        try dbWriter.write { db in
            try db.execute(
                sql: "INSERT INTO cooking_sessions(recipe_id, cooked_at, duration_seconds, rating, ingredients_rescued_json) VALUES (?, ?, ?, ?, ?);",
                arguments: [recipeId, timestamp, durationSeconds, rating, rescuedJSON]
            )
        }
    }

    /// Returns recent cooking sessions joined with recipe titles, including deserialised rescued-ingredient lists.
    func getCookingSessions(limit: Int) throws -> [CookingSession] {
        return try dbWriter.read { db in
            let sql = """
                SELECT cs.id, cs.recipe_id, cs.cooked_at, cs.duration_seconds, cs.rating, cs.ingredients_rescued_json, r.title AS recipe_title
                FROM cooking_sessions cs
                LEFT JOIN recipes r ON r.id = cs.recipe_id
                ORDER BY cs.cooked_at DESC
                LIMIT ?;
            """
            return try Row.fetchAll(db, sql: sql, arguments: [limit]).map { row in
                let id: Int = row["id"]
                let recipeId: Int = row["recipe_id"]
                let recipeTitle: String = row["recipe_title"] ?? ""
                let cookedAtTimestamp: Int = row["cooked_at"]
                let durationSeconds: Int? = row["duration_seconds"]
                let rating: Int? = row["rating"]
                let rescuedIngredientsJSON: String? = row["ingredients_rescued_json"]
                let rescuedIngredients = rescuedIngredientsJSON
                    .flatMap { $0.data(using: .utf8) }
                    .flatMap { try? decoder.decode([String].self, from: $0) }?
                    .map(Ingredient.init(name:)) ?? []
                return CookingSession(
                    id: id,
                    recipeId: recipeId,
                    recipeTitle: recipeTitle,
                    cookedAt: Date(timeIntervalSince1970: TimeInterval(cookedAtTimestamp)),
                    durationSeconds: durationSeconds.map { TimeInterval($0) },
                    rating: rating,
                    rescuedIngredients: rescuedIngredients
                )
            }
        }
    }

    /// Returns the timestamps of all cooking sessions within an inclusive date range.
    func getCookingSessionDates(from startDate: Date, to endDate: Date) throws -> [Date] {
        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = Int(endDate.timeIntervalSince1970)
        return try dbWriter.read { db in
            let sql = """
                SELECT cooked_at FROM cooking_sessions
                WHERE cooked_at >= ? AND cooked_at <= ?
                ORDER BY cooked_at ASC;
            """
            return try Row.fetchAll(db, sql: sql, arguments: [startTimestamp, endTimestamp]).map { row in
                let timestamp: Int = row["cooked_at"]
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
        }
    }

    /// Returns the total number of recorded cooking sessions.
    func getCookingSessionCount() throws -> Int {
        return try dbWriter.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM cooking_sessions;") ?? 0
        }
    }

    /// Returns the cumulative duration of all cooking sessions as a `TimeInterval` (seconds).
    func getTotalCookingDuration() throws -> TimeInterval {
        return try dbWriter.read { db in
            let total = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(duration_seconds), 0) FROM cooking_sessions;") ?? 0
            return TimeInterval(total)
        }
    }

    /// Returns the number of cooking sessions within a half-open date range `[startDate, endDate)`.
    func getCookingSessionCount(from startDate: Date, to endDate: Date) throws -> Int {
        return try dbWriter.read { db in
            let count = try Int.fetchOne(db,
                sql: "SELECT COUNT(*) FROM cooking_sessions WHERE cooked_at >= ? AND cooked_at < ?",
                arguments: [startDate.timeIntervalSince1970, endDate.timeIntervalSince1970])
            return count ?? 0
        }
    }

    /// Returns the count of distinct ingredients cooked within a date range.
    ///
    /// Uses a `UNION` query over two paths to handle both session types:
    /// 1. Sessions **with** `ingredients_rescued_json`: expands the JSON array via SQLite's
    ///    `json_each()` to obtain the explicitly-recorded ingredient names.
    /// 2. Sessions **without** `ingredients_rescued_json`: joins `recipe_ingredients` to get
    ///    the default ingredient list for the cooked recipe.
    ///
    /// This dual-path design ensures accurate statistics whether the user cooked the recipe
    /// as-is or substituted ingredients.
    func getDistinctCookedIngredientCount(from startDate: Date, to endDate: Date) throws -> Int {
        return try dbWriter.read { db in
            let count = try Int.fetchOne(db,
                sql: """
                    SELECT COUNT(DISTINCT ingredient_name) FROM (
                        SELECT json_each.value AS ingredient_name
                        FROM cooking_sessions, json_each(cooking_sessions.ingredients_rescued_json)
                        WHERE cooking_sessions.ingredients_rescued_json IS NOT NULL
                        AND cooking_sessions.cooked_at >= ? AND cooking_sessions.cooked_at < ?
                        UNION
                        SELECT ri.ingredient_name
                        FROM cooking_sessions cs
                        JOIN recipe_ingredients ri ON cs.recipe_id = ri.recipe_id
                        WHERE cs.ingredients_rescued_json IS NULL
                        AND cs.cooked_at >= ? AND cs.cooked_at < ?
                    )
                    """,
                arguments: [startDate.timeIntervalSince1970, endDate.timeIntervalSince1970,
                            startDate.timeIntervalSince1970, endDate.timeIntervalSince1970])
            return count ?? 0
        }
    }

    // MARK: - User-Created Recipes

    /// Returns all user-created recipes (`is_user_created = 1`), sorted by id descending (newest first).
    func getUserCreatedRecipes() throws -> [Recipe] {
        return try dbWriter.read { db in
            let sql = """
                SELECT \(Self.recipeColumns)
                FROM recipes r
                WHERE r.is_user_created = 1
                ORDER BY r.id DESC;
            """
            return try Row.fetchAll(db, sql: sql).compactMap { row in
                try? decodeRecipe(from: row)
            }
        }
    }

    /// Returns the count of user-created recipes.
    func getUserCreatedRecipeCount() throws -> Int {
        return try dbWriter.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipes WHERE is_user_created = 1;") ?? 0
        }
    }

    /// Sets `isUserCreated = true` on the recipe and delegates to `insertRecipes(_:)`.
    func insertUserRecipe(_ recipe: Recipe) throws {
        var userRecipe = recipe
        userRecipe.isUserCreated = true
        try insertRecipes([userRecipe])
    }

    /// Updates all mutable fields of a user-created recipe and rebuilds its `recipe_ingredients` links.
    ///
    /// After the `UPDATE`, the existing `recipe_ingredients` rows for this recipe are deleted and
    /// re-inserted from `recipe.ingredients`, deduplicating ingredient names in the same way as
    /// `insertRecipes(_:)`. The recipe is then evicted from `recipeCache` so subsequent reads
    /// pick up the new data.
    /// - Throws: `DatabaseError.recipeNotFound` if no recipe with this title exists.
    func updateUserRecipe(_ recipe: Recipe) throws {
        guard let recipeId = try getRecipeId(byTitle: recipe.title) else {
            throw DatabaseError.recipeNotFound(recipe.title)
        }
        let instructionsJSON = try String(data: encoder.encode(recipe.instructions), encoding: .utf8) ?? "[]"
        let ingredientsJSON = try String(data: encoder.encode(recipe.ingredients), encoding: .utf8) ?? "[]"
        let additionalJSON = try String(data: encoder.encode(recipe.additionalInfo), encoding: .utf8) ?? "{}"

        try dbWriter.write { db in
            let sql = """
                UPDATE recipes SET
                    title = ?, image = ?, instructions_json = ?, ingredients_json = ?,
                    additional_info_json = ?, source = ?,
                    tagline = ?, user_rating = ?, api_rating = ?, author = ?,
                    emoji = ?, cuisine = ?
                WHERE id = ?;
            """
            try db.execute(sql: sql, arguments: [
                recipe.title, recipe.image, instructionsJSON, ingredientsJSON,
                additionalJSON, recipe.source?.rawValue,
                recipe.tagline, recipe.userRating, recipe.apiRating, recipe.author,
                recipe.emoji, recipe.cuisine, recipeId
            ])

            try db.execute(sql: "DELETE FROM recipe_ingredients WHERE recipe_id = ?;", arguments: [recipeId])
            var seen: Set<String> = []
            for ing in recipe.ingredients {
                let name = ing.name
                if seen.contains(name) { continue }
                seen.insert(name)
                try db.execute(
                    sql: "INSERT INTO recipe_ingredients(recipe_id, ingredient_name) VALUES(?, ?);",
                    arguments: [recipeId, name]
                )
            }
        }
        removeCachedRecipe(forTitle: recipe.title)
    }

    /// Deletes a user-created recipe. The `AND is_user_created = 1` guard prevents accidental
    /// deletion of seeded recipes by ID collision.
    func deleteUserRecipe(recipeId: Int) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM recipes WHERE id = ? AND is_user_created = 1;",
                arguments: [recipeId]
            )
        }
    }

    // MARK: - Ingredient Queries

    /// Returns all ingredients, optionally filtered to a specific food group, sorted alphabetically.
    /// - Parameters:
    ///   - foodGroup: Optional food group to filter by (e.g. `"Vegetables"`). `nil` returns all groups.
    ///   - limit: Maximum number of results (default 100).
    func getAllIngredients(inGroup foodGroup: String? = nil, limit: Int = 100) throws -> [Ingredient] {
        return try dbWriter.read { db in
            let sql: String
            let arguments: StatementArguments
            if let foodGroup {
                sql = """
                    SELECT name, description, picture_file_name, food_group, food_subgroup
                    FROM ingredients
                    WHERE food_group = ?
                    ORDER BY name ASC
                    LIMIT ?;
                """
                arguments = [foodGroup, limit]
            } else {
                sql = """
                    SELECT name, description, picture_file_name, food_group, food_subgroup
                    FROM ingredients
                    ORDER BY name ASC
                    LIMIT ?;
                """
                arguments = [limit]
            }
            return try Row.fetchAll(db, sql: sql, arguments: arguments).map { row in
                Ingredient(
                    name: row["name"],
                    description: row["description"],
                    pictureFileName: row["picture_file_name"],
                    foodGroup: row["food_group"],
                    foodSubgroup: row["food_subgroup"]
                )
            }
        }
    }

    /// Returns all distinct non-null food group values in the `ingredients` table, sorted alphabetically.
    func getDistinctFoodGroups() throws -> [String] {
        return try dbWriter.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT DISTINCT food_group FROM ingredients WHERE food_group IS NOT NULL ORDER BY food_group ASC;"
            )
        }
    }

    // MARK: - Pantry

    /// Returns the user's pantry staples by joining `pantry_items` back to canonical ingredient rows.
    func getPantryItems() throws -> [Ingredient] {
        try dbWriter.read { db in
            let sql = """
                SELECT i.name, i.description, i.picture_file_name, i.food_group, i.food_subgroup
                FROM pantry_items pi
                INNER JOIN ingredients i ON i.name = pi.ingredient_name
                ORDER BY pi.added_at DESC;
            """
            return try Row.fetchAll(db, sql: sql).map(Self.decodeIngredient(from:))
        }
    }

    /// Marks an ingredient as a pantry staple using the canonical stored ingredient name.
    ///
    /// Resolving through `ingredients` keeps the foreign key valid and prevents duplicate rows
    /// caused by casing differences such as "salt" vs. "Salt".
    func addPantryItem(_ ingredient: Ingredient) throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        try dbWriter.write { db in
            guard let actualName = try Self.canonicalIngredientName(for: ingredient.name, in: db) else {
                throw DatabaseError.ingredientNotFound(ingredient.name)
            }

            try db.execute(
                sql: """
                    INSERT INTO pantry_items (ingredient_name, added_at)
                    VALUES (?, ?)
                    ON CONFLICT(ingredient_name) DO UPDATE SET
                        added_at = excluded.added_at;
                    """,
                arguments: [actualName, timestamp]
            )
        }
    }

    /// Removes an ingredient from the pantry, matching case-insensitively.
    func removePantryItem(_ ingredient: Ingredient) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM pantry_items WHERE ingredient_name = ? COLLATE NOCASE;",
                arguments: [ingredient.name]
            )
        }
    }

    /// Checks pantry membership case-insensitively against `ingredient_name`.
    func isPantryItem(_ ingredient: Ingredient) throws -> Bool {
        try dbWriter.read { db in
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM pantry_items WHERE ingredient_name = ? COLLATE NOCASE;",
                arguments: [ingredient.name]
            ) ?? 0
            return count > 0
        }
    }

    // MARK: - Internal Helpers (used by services)

    /// Gets the database ID for a recipe by its title
    /// - Parameter title: The recipe title
    /// - Returns: The database ID if found, nil otherwise
    func getRecipeId(byTitle title: String) throws -> Int? {
        return try dbWriter.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT id FROM recipes WHERE title = ? LIMIT 1;",
                arguments: [title]
            )
        }
    }

    // MARK: - Shopping List

    /// Returns all shopping list items ordered by `added_at` ascending (oldest first).
    func getShoppingItems() throws -> [ShoppingItem] {
        try dbWriter.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, is_checked, added_at, recipe_title FROM shopping_items ORDER BY added_at ASC;").map { row in
                ShoppingItem(
                    id: row["id"],
                    name: row["name"],
                    isChecked: (row["is_checked"] as Int) == 1,
                    addedAt: Date(timeIntervalSince1970: TimeInterval(row["added_at"] as Int)),
                    recipeTitle: row["recipe_title"]
                )
            }
        }
    }

    /// Inserts multiple shopping items in a single write transaction and returns the persisted records.
    /// All items share the same `added_at` timestamp and optional `recipeTitle`.
    func addShoppingItems(_ names: [String], recipeTitle: String?) throws -> [ShoppingItem] {
        let timestamp = Int(Date().timeIntervalSince1970)
        var inserted: [ShoppingItem] = []
        try dbWriter.write { db in
            for name in names {
                try db.execute(
                    sql: "INSERT INTO shopping_items(name, is_checked, added_at, recipe_title) VALUES (?, 0, ?, ?);",
                    arguments: [name, timestamp, recipeTitle]
                )
                let id = Int(db.lastInsertedRowID)
                inserted.append(ShoppingItem(
                    id: id,
                    name: name,
                    isChecked: false,
                    addedAt: Date(timeIntervalSince1970: TimeInterval(timestamp)),
                    recipeTitle: recipeTitle
                ))
            }
        }
        return inserted
    }

    /// Atomically reads the current `is_checked` state and writes its opposite.
    /// - Returns: `true` if the item is now checked, `false` if now unchecked.
    func toggleShoppingItem(id: Int) throws -> Bool {
        try dbWriter.write { db in
            let current = try Int.fetchOne(db, sql: "SELECT is_checked FROM shopping_items WHERE id = ?;", arguments: [id]) ?? 0
            let newValue = current == 0 ? 1 : 0
            try db.execute(sql: "UPDATE shopping_items SET is_checked = ? WHERE id = ?;", arguments: [newValue, id])
            return newValue == 1
        }
    }

    /// Deletes a shopping item by primary key.
    func removeShoppingItem(id: Int) throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM shopping_items WHERE id = ?;", arguments: [id])
        }
    }

    /// Deletes all shopping items where `is_checked = 1`.
    func clearCheckedShoppingItems() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM shopping_items WHERE is_checked = 1;")
        }
    }

    // MARK: - Statistics

    /// Returns the total number of recipes in the database (seeded + user-created).
    func getRecipeCount() throws -> Int {
        return try dbWriter.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM recipes;"
            ) ?? 0
        }
    }

    /// Returns the count of distinct ingredients across all cooking sessions (all time).
    ///
    /// Uses the same `UNION` logic as the date-ranged variant: sessions with
    /// `ingredients_rescued_json` expand that JSON array; sessions without it join
    /// `recipe_ingredients` for the recipe's default ingredient list.
    func getDistinctCookedIngredientCount() throws -> Int {
        return try dbWriter.read { db in
            let sql = """
                SELECT COUNT(DISTINCT ingredient_name) FROM (
                    SELECT json_each.value AS ingredient_name
                    FROM cooking_sessions, json_each(cooking_sessions.ingredients_rescued_json)
                    WHERE cooking_sessions.ingredients_rescued_json IS NOT NULL
                    UNION
                    SELECT ri.ingredient_name
                    FROM cooking_sessions cs
                    JOIN recipe_ingredients ri ON cs.recipe_id = ri.recipe_id
                    WHERE cs.ingredients_rescued_json IS NULL
                )
            """
            return try Int.fetchOne(db, sql: sql) ?? 0
        }
    }

    // MARK: - Private Helpers

    /// Decodes a `Recipe` from a GRDB `Row` matching the shape defined by `recipeColumns`.
    ///
    /// **Migration fallback for `instructions_json`**: older database rows may store instructions
    /// as a JSON array of plain strings (`[String]`) rather than the current `[Recipe.Step]` format.
    /// The decoder first attempts `[Recipe.Step]` decoding; on failure it retries as `[String]` and
    /// converts each string to a `Recipe.Step` via `Step.init(plainText:)`, ensuring backward
    /// compatibility without requiring a schema migration.
    private func decodeRecipe(from row: Row) throws -> Recipe {
        let title: String = row["title"]
        let image: String = row["image"]
        let instructionsJSON: String = row["instructions_json"]
        let ingredientsJSON: String = row["ingredients_json"]
        let additionalJSON: String = row["additional_info_json"]
        let sourceRaw: String? = row["source"]
        let source = sourceRaw.flatMap { RecipeSourceType(rawValue: $0) }

        let instructions: [Recipe.Step]
        do {
            instructions = try decoder.decode([Recipe.Step].self, from: Data(instructionsJSON.utf8))
        } catch {
            let strings = try decoder.decode([String].self, from: Data(instructionsJSON.utf8))
            instructions = strings.map(Recipe.Step.init(plainText:))
        }
        let ingredients = try decoder.decode([Ingredient].self, from: Data(ingredientsJSON.utf8))
        let additionalInfo = try decoder.decode(Recipe.AdditionalInfo.self, from: Data(additionalJSON.utf8))

        let tagline: String? = row["tagline"]
        let userRating: Double? = row["user_rating"]
        let apiRating: Double? = row["api_rating"]
        let author: String? = row["author"]
        let isUserCreated: Bool = (row["is_user_created"] as Int?) == 1
        let emoji: String? = row["emoji"]
        let cuisine: String? = row["cuisine"]

        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            image: image,
            additionalInfo: additionalInfo,
            source: source,
            tagline: tagline,
            userRating: userRating,
            apiRating: apiRating,
            author: author,
            isUserCreated: isUserCreated,
            emoji: emoji,
            cuisine: cuisine
        )
    }

    /// Decodes a canonical ingredient row returned by database joins.
    private static func decodeIngredient(from row: Row) -> Ingredient {
        Ingredient(
            name: row["name"],
            description: row["description"],
            pictureFileName: row["picture_file_name"],
            foodGroup: row["food_group"],
            foodSubgroup: row["food_subgroup"]
        )
    }

    /// Resolves an ingredient name to the stored primary-key casing, if it exists.
    private static func canonicalIngredientName(for name: String, in db: Database) throws -> String? {
        try String.fetchOne(
            db,
            sql: "SELECT name FROM ingredients WHERE name = ? COLLATE NOCASE LIMIT 1;",
            arguments: [name]
        )
    }

    // MARK: - Test convenience & removal APIs used by tests
    /// Removes a single ingredient by name; delegates to `removeIngredients(_:)`.
    func removeIngredient(named name: String) throws {
        try removeIngredients([name])
    }

    /// Removes multiple ingredients by name using a single `DELETE … WHERE name IN (…)` statement.
    func removeIngredients(_ names: [String]) throws {
        guard !names.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: names.count).joined(separator: ",")
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM ingredients WHERE name IN (\(placeholders));", arguments: StatementArguments(names))
            // Clear test helpers if available
            testHelpers?.clearVariants()
        }
    }

    /// Removes all rows from the `ingredients` table.
    func removeAllIngredients() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM ingredients;")
            testHelpers?.clearVariants()
        }
    }

    /// Removes a single recipe by title; delegates to `removeRecipes(withTitles:)`.
    func removeRecipe(withTitle title: String) throws {
        try removeRecipes(withTitles: [title])
    }

    /// Removes all rows from both `recipes` and `recipe_ingredients`.
    func removeAllRecipes() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recipes;")
            try db.execute(sql: "DELETE FROM recipe_ingredients;")
        }
    }

    /// Removes all recipes that have at least one of the given ingredients linked via `recipe_ingredients`.
    /// Uses a subquery with `EXISTS` to match recipes by ingredient name.
    func removeRecipes(byIngredients ingredients: [Ingredient]) throws {
        let names = Set(ingredients.map { $0.name })
        guard !names.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: names.count).joined(separator: ",")
        let sql = """
        DELETE FROM recipes
        WHERE id IN (
            SELECT r.id FROM recipes r
            WHERE EXISTS (
                SELECT 1 FROM recipe_ingredients ri
                WHERE ri.recipe_id = r.id AND ri.ingredient_name IN (\(placeholders))
            )
        );
        """
        try dbWriter.write { db in
            try db.execute(sql: sql, arguments: StatementArguments(Array(names)))
        }
    }

    // MARK: - Private helpers
    /// Deletes recipes by title using a single `DELETE … WHERE title IN (…)` statement.
    private func removeRecipes(withTitles titles: [String]) throws {
        guard !titles.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: titles.count).joined(separator: ",")
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recipes WHERE title IN (\(placeholders));", arguments: StatementArguments(titles))
        }
    }
}
