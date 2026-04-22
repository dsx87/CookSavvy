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
final class DBInterface: DBInterfaceProtocol {
    // MARK: - DB
    private let dbWriter: DatabaseWriter

    // MARK: - JSON coders
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Logging
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "Database"
    )

    // MARK: - Test helpers (only used in test mode)
    private let testHelpers: DBTestHelpers?
    
    // MARK: - Recipe caching
    private var recipeCache: [String: Recipe] = [:]
    private let cacheQueue = DispatchQueue(label: "com.cooksavvy.database.recipe-cache")
    private let maxRecipeCacheSize = 100

    private static let recipeColumns = "r.id, r.title, r.image, r.instructions_json, r.ingredients_json, r.cleaned_ingredients_json, r.additional_info_json, r.source, r.tagline, r.user_rating, r.api_rating, r.author, r.is_user_created, r.emoji, r.cuisine"

    // MARK: - Init
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
    
    /// Initializer for testing to force in-memory
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

    convenience init(databaseURL: URL) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON;")
        }
        let writer = try DatabasePool(path: databaseURL.path, configuration: configuration)
        try self.init(dbWriter: writer, testHelpers: nil)
    }

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

            // 8. Cooking Sessions
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

            // 9. Shopping List
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

    private func cachedRecipe(from row: Row) throws -> Recipe {
        let title: String = row["title"]
        if let cachedRecipe = cachedRecipe(forTitle: title) {
            return cachedRecipe
        }

        let recipe = try decodeRecipe(from: row)
        cacheRecipe(recipe)
        return recipe
    }
    
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

    private func cachedRecipe(forTitle title: String) -> Recipe? {
        cacheQueue.sync { recipeCache[title] }
    }

    private func clearRecipeCache() {
        cacheQueue.sync {
            recipeCache.removeAll()
        }
    }

    private func removeCachedRecipe(forTitle title: String) {
        cacheQueue.sync {
            _ = recipeCache.removeValue(forKey: title)
        }
    }

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

    func insertRecipes(_ recipes: [Recipe]) throws {
        guard !recipes.isEmpty else { return }
        try dbWriter.write { db in
            for r in recipes {
                let instructionsJSON = try String(data: encoder.encode(r.instructions), encoding: .utf8) ?? "[]"
                let ingredientsJSON = try String(data: encoder.encode(r.ingredients), encoding: .utf8) ?? "[]"
                let cleanedIngredientsJSON = try String(data: encoder.encode(r.cleanedIngredients), encoding: .utf8) ?? "[]"
                let additionalJSON = try String(data: encoder.encode(r.additionalInfo), encoding: .utf8) ?? "{}"

                try db.execute(
                    sql: "INSERT INTO recipes(title, image, instructions_json, ingredients_json, cleaned_ingredients_json, additional_info_json, source, tagline, user_rating, api_rating, author, is_user_created, emoji, cuisine) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
                    arguments: [r.title, r.image, instructionsJSON, ingredientsJSON, cleanedIngredientsJSON, additionalJSON, r.source?.rawValue, r.tagline, r.userRating, r.apiRating, r.author, r.isUserCreated ? 1 : 0, r.emoji, r.cuisine]
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

    func removeIngredients(_ ingredients: [Ingredient]) throws {
        try removeIngredients(ingredients.map { $0.name })
    }

    func removeRecipes(_ recipes: [Recipe]) throws {
        let titles = recipes.map { $0.title }
        try removeRecipes(withTitles: titles)
    }

    func clearDatabase() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recent_searches;")
            try db.execute(sql: "DELETE FROM cooking_sessions;")
            try db.execute(sql: "DELETE FROM favorite_recipes;")
            try db.execute(sql: "DELETE FROM recent_recipes;")
            try db.execute(sql: "DELETE FROM recent_ingredients;")
            try db.execute(sql: "DELETE FROM recipe_ingredients;")
            try db.execute(sql: "DELETE FROM recipes;")
            try db.execute(sql: "DELETE FROM ingredients;")
            try db.execute(sql: "DELETE FROM shopping_items;")

        }
        testHelpers?.clearVariants()
        clearRecipeCache()
    }

    func clearRecentData() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recent_searches;")
            try db.execute(sql: "DELETE FROM recent_recipes;")
            try db.execute(sql: "DELETE FROM recent_ingredients;")
        }
    }

    func clearFavorites() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM favorite_recipes;")
        }
    }

    // MARK: - Recent Ingredients

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

    func addFavorite(_ recipeId: Int) throws {
        let timestamp = Int(Date().timeIntervalSince1970)
        try dbWriter.write { db in
            try db.execute(
                sql: "INSERT OR IGNORE INTO favorite_recipes (recipe_id, added_at) VALUES (?, ?);",
                arguments: [recipeId, timestamp]
            )
        }
    }

    func removeFavorite(_ recipeId: Int) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM favorite_recipes WHERE recipe_id = ?;",
                arguments: [recipeId]
            )
        }
    }

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

    func recordCookingSession(recipeId: Int, date: Date, duration: TimeInterval?, rating: Int?) throws {
        try recordCookingSession(recipeId: recipeId, date: date, duration: duration, rating: rating, rescuedIngredients: nil)
    }

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

    func getCookingSessionCount() throws -> Int {
        return try dbWriter.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM cooking_sessions;") ?? 0
        }
    }

    func getTotalCookingDuration() throws -> TimeInterval {
        return try dbWriter.read { db in
            let total = try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(duration_seconds), 0) FROM cooking_sessions;") ?? 0
            return TimeInterval(total)
        }
    }

    func getCookingSessionCount(from startDate: Date, to endDate: Date) throws -> Int {
        return try dbWriter.read { db in
            let count = try Int.fetchOne(db,
                sql: "SELECT COUNT(*) FROM cooking_sessions WHERE cooked_at >= ? AND cooked_at < ?",
                arguments: [startDate.timeIntervalSince1970, endDate.timeIntervalSince1970])
            return count ?? 0
        }
    }

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

    func getUserCreatedRecipeCount() throws -> Int {
        return try dbWriter.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipes WHERE is_user_created = 1;") ?? 0
        }
    }

    func insertUserRecipe(_ recipe: Recipe) throws {
        var userRecipe = recipe
        userRecipe.isUserCreated = true
        try insertRecipes([userRecipe])
    }

    func updateUserRecipe(_ recipe: Recipe) throws {
        guard let recipeId = try getRecipeId(byTitle: recipe.title) else {
            throw DatabaseError.recipeNotFound(recipe.title)
        }
        let instructionsJSON = try String(data: encoder.encode(recipe.instructions), encoding: .utf8) ?? "[]"
        let ingredientsJSON = try String(data: encoder.encode(recipe.ingredients), encoding: .utf8) ?? "[]"
        let cleanedIngredientsJSON = try String(data: encoder.encode(recipe.cleanedIngredients), encoding: .utf8) ?? "[]"
        let additionalJSON = try String(data: encoder.encode(recipe.additionalInfo), encoding: .utf8) ?? "{}"

        try dbWriter.write { db in
            let sql = """
                UPDATE recipes SET
                    title = ?, image = ?, instructions_json = ?, ingredients_json = ?,
                    cleaned_ingredients_json = ?, additional_info_json = ?, source = ?,
                    tagline = ?, user_rating = ?, api_rating = ?, author = ?,
                    emoji = ?, cuisine = ?
                WHERE id = ?;
            """
            try db.execute(sql: sql, arguments: [
                recipe.title, recipe.image, instructionsJSON, ingredientsJSON,
                cleanedIngredientsJSON, additionalJSON, recipe.source?.rawValue,
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

    func deleteUserRecipe(recipeId: Int) throws {
        try dbWriter.write { db in
            try db.execute(
                sql: "DELETE FROM recipes WHERE id = ? AND is_user_created = 1;",
                arguments: [recipeId]
            )
        }
    }

    // MARK: - Ingredient Queries

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

    func getDistinctFoodGroups() throws -> [String] {
        return try dbWriter.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT DISTINCT food_group FROM ingredients WHERE food_group IS NOT NULL ORDER BY food_group ASC;"
            )
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

    func toggleShoppingItem(id: Int) throws -> Bool {
        try dbWriter.write { db in
            let current = try Int.fetchOne(db, sql: "SELECT is_checked FROM shopping_items WHERE id = ?;", arguments: [id]) ?? 0
            let newValue = current == 0 ? 1 : 0
            try db.execute(sql: "UPDATE shopping_items SET is_checked = ? WHERE id = ?;", arguments: [newValue, id])
            return newValue == 1
        }
    }

    func removeShoppingItem(id: Int) throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM shopping_items WHERE id = ?;", arguments: [id])
        }
    }

    func clearCheckedShoppingItems() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM shopping_items WHERE is_checked = 1;")
        }
    }

    // MARK: - Statistics

    func getRecipeCount() throws -> Int {
        return try dbWriter.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM recipes;"
            ) ?? 0
        }
    }

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

    private func decodeRecipe(from row: Row) throws -> Recipe {
        let title: String = row["title"]
        let image: String = row["image"]
        let instructionsJSON: String = row["instructions_json"]
        let ingredientsJSON: String = row["ingredients_json"]
        let cleanedIngredientsJSON: String = row["cleaned_ingredients_json"]
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
        let cleanedIngredients = try decoder.decode([Ingredient].self, from: Data(cleanedIngredientsJSON.utf8))
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
            cleanedIngredients: cleanedIngredients,
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

    // MARK: - Test convenience & removal APIs used by tests
    func removeIngredient(named name: String) throws {
        try removeIngredients([name])
    }

    func removeIngredients(_ names: [String]) throws {
        guard !names.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: names.count).joined(separator: ",")
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM ingredients WHERE name IN (\(placeholders));", arguments: StatementArguments(names))
            // Clear test helpers if available
            testHelpers?.clearVariants()
        }
    }

    func removeAllIngredients() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM ingredients;")
            testHelpers?.clearVariants()
        }
    }

    func removeRecipe(withTitle title: String) throws {
        try removeRecipes(withTitles: [title])
    }

    func removeAllRecipes() throws {
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recipes;")
            try db.execute(sql: "DELETE FROM recipe_ingredients;")
        }
    }

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
    private func removeRecipes(withTitles titles: [String]) throws {
        guard !titles.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: titles.count).joined(separator: ",")
        try dbWriter.write { db in
            try db.execute(sql: "DELETE FROM recipes WHERE title IN (\(placeholders));", arguments: StatementArguments(titles))
        }
    }
}
