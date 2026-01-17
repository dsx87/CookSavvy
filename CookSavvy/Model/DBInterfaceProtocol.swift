//
//  DBInterfaceProtocol.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import Foundation
import GRDB
import os.log

// MARK: - Database Error Types

enum DatabaseError: Error, LocalizedError {
    case recipeNotFound(String)
    case ingredientNotFound(String)
    case queryFailed(String, underlying: Error)
    case cacheError(String)
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

protocol DBInterfaceProtocol {
    // MARK: - Ingredients
    func getIngredients(byName name:String) throws -> [Ingredient]
    func searchIngredients(matching query: String, limit: Int) throws -> [Ingredient]
    func insertIngredients(_ ingredients: [Ingredient]) throws
    func removeIngredients(_ ingredients: [Ingredient]) throws

    // MARK: - Recipes
    func getRecipes(byIngredients: [Ingredient], offset: Int, limit: Int) throws -> [Recipe]
    func insertRecipes(_ recipes: [Recipe]) throws
    func removeRecipes(_ recipes: [Recipe]) throws

    // MARK: - Recent Ingredients
    func getRecentIngredients(limit: Int) throws -> [Ingredient]
    func getPopularIngredients(limit: Int) throws -> [Ingredient]
    func recordIngredientUsage(_ ingredient: Ingredient) throws

    // MARK: - Recent Recipes
    func getRecentRecipes(limit: Int) throws -> [Recipe]
    func recordRecipeView(_ recipeId: Int) throws

    // MARK: - Favorites
    func getFavoriteRecipes() throws -> [Recipe]
    func addFavorite(_ recipeId: Int) throws
    func removeFavorite(_ recipeId: Int) throws
    func isFavorite(_ recipeId: Int) throws -> Bool

    // MARK: - Recent Searches
    func getRecentSearches(limit: Int) throws -> [[Ingredient]]
    func recordSearch(ingredients: [Ingredient]) throws

    // MARK: - Database Management
    func clearDatabase() throws
    func clearRecentData() throws
    func clearFavorites() throws

    // MARK: - Statistics
    func getRecipeCount() throws -> Int
}

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
    private let maxRecipeCacheSize = 100

    // MARK: - Init
    init() {
        let writer: DatabaseWriter
        do {
            // 1. Define database path in Application Support
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

            // 2. Configure database
            var configuration = Configuration()
            configuration.prepareDatabase { db in
                try db.execute(sql: "PRAGMA foreign_keys = ON;")
            }

            // 3. Create DatabasePool
            writer = try DatabasePool(path: databaseURL.path, configuration: configuration)
        } catch {
            Self.logger.error("Database creation failed: \(error.localizedDescription). Falling back to in-memory.")
            let configuration = Configuration()
            writer = try! DatabaseQueue(path: ":memory:", configuration: configuration)
        }
        
        self.dbWriter = writer
        self.testHelpers = nil
        try! createSchema()
    }
    
    /// Initializer for testing to force in-memory
    init(inMemory: Bool) {
        let configuration = Configuration()
        self.dbWriter = try! DatabaseQueue(path: ":memory:", configuration: configuration)
        self.testHelpers = inMemory ? DBTestHelpers() : nil
        try! createSchema()
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
                    additional_info_json TEXT NOT NULL
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
            SELECT DISTINCT r.id, r.title, r.image, r.instructions_json, r.ingredients_json, r.cleaned_ingredients_json, r.additional_info_json
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
            
            // Check cache first
            if let cachedRecipe = recipeCache[title] {
                results.append(cachedRecipe)
                continue
            }
            
            let image: String = row["image"]
            let instructionsJSON: String = row["instructions_json"]
            let ingredientsJSON: String = row["ingredients_json"]
            let cleanedIngredientsJSON: String = row["cleaned_ingredients_json"]
            let additionalJSON: String = row["additional_info_json"]

            let instructions = try decoder.decode([String].self, from: Data(instructionsJSON.utf8))
            let ingredients = try decoder.decode([Ingredient].self, from: Data(ingredientsJSON.utf8))
            let cleanedIngredients = try decoder.decode([Ingredient].self, from: Data(cleanedIngredientsJSON.utf8))
            let additionalInfo = try decoder.decode(Recipe.AdditionalInfo.self, from: Data(additionalJSON.utf8))

            let recipe = Recipe(
                title: title,
                ingredients: ingredients,
                instructions: instructions,
                image: image,
                cleanedIngredients: cleanedIngredients,
                additionalInfo: additionalInfo
            )
            
            // Cache the recipe
            cacheRecipe(recipe)
            results.append(recipe)
        }
        
        Self.logger.info("Found \(results.count) recipes for \(ingredientNames.count) ingredients")
        return results
    }
    
    // MARK: - Private Recipe Caching Methods
    
    private func cacheRecipe(_ recipe: Recipe) {
        // Enforce cache size limit with simple FIFO
        if recipeCache.count >= maxRecipeCacheSize {
            if let firstKey = recipeCache.keys.first {
                recipeCache.removeValue(forKey: firstKey)
            }
        }
        recipeCache[recipe.title] = recipe
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
                    sql: "INSERT INTO recipes(title, image, instructions_json, ingredients_json, cleaned_ingredients_json, additional_info_json) VALUES (?, ?, ?, ?, ?, ?);",
                    arguments: [r.title, r.image, instructionsJSON, ingredientsJSON, cleanedIngredientsJSON, additionalJSON]
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
            try db.execute(sql: "DELETE FROM favorite_recipes;")
            try db.execute(sql: "DELETE FROM recent_recipes;")
            try db.execute(sql: "DELETE FROM recent_ingredients;")
            try db.execute(sql: "DELETE FROM recipe_ingredients;")
            try db.execute(sql: "DELETE FROM recipes;")
            try db.execute(sql: "DELETE FROM ingredients;")
            // FTS tables are cleared automatically via triggers or we can explicitly clear them if needed,
            // but DELETE FROM main_table triggers DELETE on FTS.

            testHelpers?.clearVariants()
            recipeCache.removeAll()
        }
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
                SELECT r.id, r.title, r.image, r.instructions_json, r.ingredients_json, r.cleaned_ingredients_json, r.additional_info_json
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
                SELECT r.id, r.title, r.image, r.instructions_json, r.ingredients_json, r.cleaned_ingredients_json, r.additional_info_json
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

    // MARK: - Statistics

    func getRecipeCount() throws -> Int {
        return try dbWriter.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM recipes;"
            ) ?? 0
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

        let instructions = try decoder.decode([String].self, from: Data(instructionsJSON.utf8))
        let ingredients = try decoder.decode([Ingredient].self, from: Data(ingredientsJSON.utf8))
        let cleanedIngredients = try decoder.decode([Ingredient].self, from: Data(cleanedIngredientsJSON.utf8))
        let additionalInfo = try decoder.decode(Recipe.AdditionalInfo.self, from: Data(additionalJSON.utf8))

        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: instructions,
            image: image,
            cleanedIngredients: cleanedIngredients,
            additionalInfo: additionalInfo
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
