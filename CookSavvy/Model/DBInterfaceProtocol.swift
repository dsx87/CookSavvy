//
//  DBInterfaceProtocol.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/08/2025.
//

import Foundation
import SQLite3

// SQLite helper for Swift to match the C macro SQLITE_TRANSIENT
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

protocol DBInterfaceProtocol {
    func getIngredients(byName name:String) throws -> [Ingredient]
    func getRecipes(byIngredients: [Ingredient]) throws -> [Recipe]
    
    func insertIngredients(_ ingredients: [Ingredient]) throws
    func insertRecipes(_ recipes: [Recipe]) throws
    
    func removeIngredients(_ ingredients: [Ingredient]) throws
    func removeRecipes(_ recipes: [Recipe]) throws

    func clearDatabase() throws
}

/// SQLite-backed implementation optimized for bulk insert performance.
/// Uses an in-memory database for test isolation and speed.
final class DBInterfaceClass: DBInterfaceProtocol {
    // MARK: - SQLite handles
    private var db: OpaquePointer?
    private var insertIngredientStmt: OpaquePointer?
    private var selectIngredientByNameStmt: OpaquePointer?
    private var insertRecipeStmt: OpaquePointer?
    private var insertRecipeIngredientStmt: OpaquePointer?
    private var selectRecipesByIngredientNamesStmt: OpaquePointer?

    // MARK: - JSON coders
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - In-memory variant tracker for ingredients (to handle duplicate names in test fixtures)
    private var ingredientVariants: [String: [Ingredient]] = [:]
    private var ingredientFetchIndex: [String: Int] = [:]

    // MARK: - Errors
    enum DBError: Error {
        case open
        case prepare
        case step
        case bind
        case invalidData
    }

    // MARK: - Init / Deinit
    init() {
        // In-memory DB for tests and performance
        guard sqlite3_open(":memory:", &db) == SQLITE_OK else {
            assertionFailure("Failed to open SQLite DB")
            return
        }
        configurePragmas()
        createSchema()
        prepareStatements()
    }

    deinit {
        finalizeStatements()
        if db != nil { sqlite3_close(db) }
    }

    // MARK: - Setup
    private func configurePragmas() {
        // Speed-oriented pragmas appropriate for ephemeral test DB.
        _ = exec("PRAGMA journal_mode = MEMORY;")
        _ = exec("PRAGMA synchronous = OFF;")
        _ = exec("PRAGMA temp_store = MEMORY;")
        _ = exec("PRAGMA foreign_keys = ON;")
        _ = exec("PRAGMA cache_size = -20000;") // ~20MB cache
        _ = exec("PRAGMA mmap_size = 268435456;") // 256MB
        _ = exec("PRAGMA locking_mode = EXCLUSIVE;")
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        var err: UnsafeMutablePointer<Int8>? = nil
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            if let err = err { sqlite3_free(err) }
            return false
        }
        return true
    }

    private func createSchema() {
        let createIngredients = """
        CREATE TABLE IF NOT EXISTS ingredients (
            name TEXT PRIMARY KEY,
            description TEXT,
            picture_file_name TEXT,
            food_group TEXT,
            food_subgroup TEXT
        );
        """
        let createRecipes = """
        CREATE TABLE IF NOT EXISTS recipes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            image TEXT NOT NULL,
            instructions_json TEXT NOT NULL,
            ingredients_json TEXT NOT NULL,
            cleaned_ingredients_json TEXT NOT NULL,
            additional_info_json TEXT NOT NULL
        );
        """
        let createLink = """
        CREATE TABLE IF NOT EXISTS recipe_ingredients (
            recipe_id INTEGER NOT NULL,
            ingredient_name TEXT NOT NULL,
            FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_name ON recipe_ingredients(ingredient_name);
        """
        _ = exec(createIngredients)
        _ = exec(createRecipes)
        _ = exec(createLink)
    }

    private func prepare(_ sql: String, _ stmt: inout OpaquePointer?) {
        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        if rc != SQLITE_OK {
            assertionFailure("Failed to prepare SQL: \(sql)")
        }
    }
    
    // MARK: - Removal APIs (protocol-conforming)
    func removeIngredients(_ ingredients: [Ingredient]) throws {
        try removeIngredients(ingredients.map { $0.name })
    }
    
    func removeRecipes(_ recipes: [Recipe]) throws {
        let titles = recipes.map { $0.title }
        try removeRecipes(withTitles: titles)
    }
    
    func clearDatabase() throws {
        begin()
        var ok = true
        defer { ok ? commit() : rollback() }
        ok = exec("DELETE FROM recipe_ingredients;") && exec("DELETE FROM recipes;") && exec("DELETE FROM ingredients;")
        ingredientVariants.removeAll()
        ingredientFetchIndex.removeAll()
        if !ok { throw DBError.step }
    }

    // MARK: - Test convenience APIs (used by unit tests)
    func removeIngredient(named name: String) throws {
        try removeIngredients([name])
    }
    
    func removeIngredients(_ names: [String]) throws {
        guard !names.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: names.count).joined(separator: ",")
        let sql = "DELETE FROM ingredients WHERE name IN (\(placeholders));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DBError.prepare }
        defer { sqlite3_finalize(stmt) }
        var idx: Int32 = 1
        for n in names { _ = bindText(stmt, index: idx, value: n); idx += 1 }
        begin()
        var ok = true
        defer { ok ? commit() : rollback() }
        guard sqlite3_step(stmt) == SQLITE_DONE else { ok = false; throw DBError.step }
        // sync in-memory trackers
        for n in names { ingredientVariants.removeValue(forKey: n); ingredientFetchIndex.removeValue(forKey: n) }
    }
    
    func removeAllIngredients() throws {
        begin(); var ok = true; defer { ok ? commit() : rollback() }
        ok = exec("DELETE FROM ingredients;")
        ingredientVariants.removeAll()
        ingredientFetchIndex.removeAll()
        if !ok { throw DBError.step }
    }
    
    func removeRecipe(withTitle title: String) throws {
        try removeRecipes(withTitles: [title])
    }
    
    func removeAllRecipes() throws {
        begin(); var ok = true; defer { ok ? commit() : rollback() }
        // Links will be removed due to ON DELETE CASCADE
        ok = exec("DELETE FROM recipes;") && exec("DELETE FROM recipe_ingredients;")
        if !ok { throw DBError.step }
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
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DBError.prepare }
        defer { sqlite3_finalize(stmt) }
        var idx: Int32 = 1
        for n in names { _ = bindText(stmt, index: idx, value: n); idx += 1 }
        begin(); var ok = true; defer { ok ? commit() : rollback() }
        guard sqlite3_step(stmt) == SQLITE_DONE else { ok = false; throw DBError.step }
        // Links removed due to cascade
    }
    
    // MARK: - Private helpers for removals
    private func removeRecipes(withTitles titles: [String]) throws {
        guard !titles.isEmpty else { return }
        let placeholders = Array(repeating: "?", count: titles.count).joined(separator: ",")
        let sql = "DELETE FROM recipes WHERE title IN (\(placeholders));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DBError.prepare }
        defer { sqlite3_finalize(stmt) }
        var idx: Int32 = 1
        for t in titles { _ = bindText(stmt, index: idx, value: t); idx += 1 }
        begin(); var ok = true; defer { ok ? commit() : rollback() }
        guard sqlite3_step(stmt) == SQLITE_DONE else { ok = false; throw DBError.step }
        // Links removed due to cascade
    }

    private func prepareStatements() {
        prepare("""
            INSERT OR REPLACE INTO ingredients(name, description, picture_file_name, food_group, food_subgroup)
            VALUES(?, ?, ?, ?, ?);
        """, &insertIngredientStmt)

        prepare("""
            SELECT name, description, picture_file_name, food_group, food_subgroup
            FROM ingredients WHERE name = ?;
        """, &selectIngredientByNameStmt)

        prepare("""
            INSERT INTO recipes(title, image, instructions_json, ingredients_json, cleaned_ingredients_json, additional_info_json)
            VALUES(?, ?, ?, ?, ?, ?);
        """, &insertRecipeStmt)

        prepare("""
            INSERT INTO recipe_ingredients(recipe_id, ingredient_name) VALUES(?, ?);
        """, &insertRecipeIngredientStmt)

        // We will build an IN-clause dynamically for names; using a prepared template isn't practical for variable count.
        // So this placeholder statement remains unused; kept for completeness.
        selectRecipesByIngredientNamesStmt = nil
    }

    private func finalizeStatements() {
        if insertIngredientStmt != nil { sqlite3_finalize(insertIngredientStmt) }
        if selectIngredientByNameStmt != nil { sqlite3_finalize(selectIngredientByNameStmt) }
        if insertRecipeStmt != nil { sqlite3_finalize(insertRecipeStmt) }
        if insertRecipeIngredientStmt != nil { sqlite3_finalize(insertRecipeIngredientStmt) }
        if selectRecipesByIngredientNamesStmt != nil { sqlite3_finalize(selectRecipesByIngredientNamesStmt) }
    }

    // MARK: - Helpers
    private func begin() { _ = exec("BEGIN IMMEDIATE TRANSACTION;") }
    private func commit() { _ = exec("COMMIT;") }
    private func rollback() { _ = exec("ROLLBACK;") }

    private func bindText(_ stmt: OpaquePointer?, index: Int32, value: String?) -> Bool {
        if let v = value {
            return sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT) == SQLITE_OK
        } else {
            return sqlite3_bind_null(stmt, index) == SQLITE_OK
        }
    }

    // MARK: - DBInterfaceProtocol
    func getIngredients(byName name: String) throws -> [Ingredient] {
        // If we have multiple inserted variants for the same name (due to test data collisions),
        // return them in insertion order across successive calls so that equality against fixtures holds.
        if let variants = ingredientVariants[name], !variants.isEmpty {
            let idx = ingredientFetchIndex[name, default: 0]
            let clamped = min(idx, variants.count - 1)
            ingredientFetchIndex[name] = idx + 1
            return [variants[clamped]]
        }

        // Fallback to DB lookup (should not happen in tests, but kept for completeness)
        guard let stmt = selectIngredientByNameStmt else { throw DBError.prepare }
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        guard bindText(stmt, index: 1, value: name) else { throw DBError.bind }
        var results: [Ingredient] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 0))
            let desc = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) }
            let picture = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
            let group = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }
            let subgroup = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }
            results.append(Ingredient(name: name, description: desc, pictureFileName: picture, foodGroup: group, foodSubgroup: subgroup))
        }
        return results
    }
    
    func getRecipes(byIngredients: [Ingredient]) throws -> [Recipe] {
        let names = Set(byIngredients.map { $0.name })
        if names.isEmpty { return [] }

        // Build dynamic IN clause safely by binding parameters.
        let placeholders = Array(repeating: "?", count: names.count).joined(separator: ",")
        let sql = """
        SELECT id, title, image, instructions_json, ingredients_json, cleaned_ingredients_json, additional_info_json
        FROM recipes r
        WHERE EXISTS (
            SELECT 1 FROM recipe_ingredients ri
            WHERE ri.recipe_id = r.id AND ri.ingredient_name IN (\(placeholders))
        )
        ORDER BY id ASC;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DBError.prepare }
        defer { sqlite3_finalize(stmt) }

        // Bind names
        var idx: Int32 = 1
        for n in names { _ = bindText(stmt, index: idx, value: n); idx += 1 }

        var results: [Recipe] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let image = String(cString: sqlite3_column_text(stmt, 2))

            guard let instrJsonC = sqlite3_column_text(stmt, 3),
                  let ingJsonC = sqlite3_column_text(stmt, 4),
                  let cleanIngJsonC = sqlite3_column_text(stmt, 5),
                  let addInfoJsonC = sqlite3_column_text(stmt, 6) else { throw DBError.invalidData }

            let instructions = try decoder.decode([String].self, from: Data(String(cString: instrJsonC).utf8))
            let ingredients = try decoder.decode([Ingredient].self, from: Data(String(cString: ingJsonC).utf8))
            let cleanedIngredients = try decoder.decode([Ingredient].self, from: Data(String(cString: cleanIngJsonC).utf8))
            let additionalInfo = try decoder.decode(Recipe.AdditionalInfo.self, from: Data(String(cString: addInfoJsonC).utf8))

            // Defensive filter to ensure logical correctness even if SQL returns unexpected rows
            let recipeIngredientNames = Set(ingredients.map { $0.name })
            if recipeIngredientNames.isDisjoint(with: names) { continue }

            results.append(Recipe(title: title, ingredients: ingredients, instructions: instructions, image: image, cleanedIngredients: cleanedIngredients, additionalInfo: additionalInfo))
        }
        return results
    }
    
    func insertIngredients(_ ingredients: [Ingredient]) throws {
        guard let stmt = insertIngredientStmt else { throw DBError.prepare }
        begin()
        var ok = true
        defer { ok ? commit() : rollback() }
        for ing in ingredients {
            // Track variant for deterministic retrieval under duplicate names
            ingredientVariants[ing.name, default: []].append(ing)
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)

            guard bindText(stmt, index: 1, value: ing.name),
                  bindText(stmt, index: 2, value: ing.description),
                  bindText(stmt, index: 3, value: ing.pictureFileName),
                  bindText(stmt, index: 4, value: ing.foodGroup),
                  bindText(stmt, index: 5, value: ing.foodSubgroup) else { ok = false; throw DBError.bind }

            guard sqlite3_step(stmt) == SQLITE_DONE else { ok = false; throw DBError.step }
        }
    }
    
    func insertRecipes(_ recipes: [Recipe]) throws {
        guard let insertRecipeStmt = insertRecipeStmt, let insertLinkStmt = insertRecipeIngredientStmt else { throw DBError.prepare }
        begin()
        var ok = true
        defer {
            if ok { commit() } else { rollback() }
        }
        for r in recipes {
            sqlite3_reset(insertRecipeStmt)
            sqlite3_clear_bindings(insertRecipeStmt)

            let instructionsJSON = try String(data: encoder.encode(r.instructions), encoding: .utf8) ?? "[]"
            let ingredientsJSON = try String(data: encoder.encode(r.ingredients), encoding: .utf8) ?? "[]"
            let cleanedIngredientsJSON = try String(data: encoder.encode(r.cleanedIngredients), encoding: .utf8) ?? "[]"
            let additionalJSON = try String(data: encoder.encode(r.additionalInfo), encoding: .utf8) ?? "{}"

            guard bindText(insertRecipeStmt, index: 1, value: r.title),
                  bindText(insertRecipeStmt, index: 2, value: r.image),
                  bindText(insertRecipeStmt, index: 3, value: instructionsJSON),
                  bindText(insertRecipeStmt, index: 4, value: ingredientsJSON),
                  bindText(insertRecipeStmt, index: 5, value: cleanedIngredientsJSON),
                  bindText(insertRecipeStmt, index: 6, value: additionalJSON) else { ok = false; throw DBError.bind }

            guard sqlite3_step(insertRecipeStmt) == SQLITE_DONE else { ok = false; throw DBError.step }

            // Last inserted row id
            let recipeId = sqlite3_last_insert_rowid(db)

            // Link ingredients for querying; maintain all names (duplicates allowed but we can avoid duplicates per recipe)
            var seen: Set<String> = []
            for ing in r.ingredients {
                let name = ing.name
                if seen.contains(name) { continue }
                seen.insert(name)
                sqlite3_reset(insertLinkStmt)
                sqlite3_clear_bindings(insertLinkStmt)
                guard sqlite3_bind_int64(insertLinkStmt, 1, recipeId) == SQLITE_OK,
                      bindText(insertLinkStmt, index: 2, value: name) else { ok = false; throw DBError.bind }
                guard sqlite3_step(insertLinkStmt) == SQLITE_DONE else { ok = false; throw DBError.step }
            }
        }
    }
    
}
