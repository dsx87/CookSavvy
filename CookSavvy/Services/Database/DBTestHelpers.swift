//
//  DBTestHelpers.swift
//  CookSavvy
//
//  Created by Claude on 17/01/2026.
//

import Foundation

/// DEBUG/test-only helper providing deterministic ingredient-lookup behaviour for unit tests.
///
/// When `DBInterface` is initialised in in-memory mode it attaches a `DBTestHelpers` instance.
/// This helper intercepts `getIngredients(byName:)` calls and returns pre-registered variant
/// ingredients in round-robin order, allowing tests to control which `Ingredient` value is
/// returned for a given name without relying on real database content.
nonisolated final class DBTestHelpers {
    
    /// Maps lowercase ingredient names to all registered variants for that name.
    private var ingredientVariants: [String: [Ingredient]] = [:]
    /// Tracks the next variant index to return for each name, enabling round-robin delivery.
    private var ingredientFetchIndex: [String: Int] = [:]
    
    /// Registers additional `Ingredient` variants for their respective names.
    /// Subsequent calls to `getNextVariant(for:)` will cycle through all registered variants.
    /// - Parameter ingredients: Variants to register; grouped by `ingredient.name.lowercased()`.
    func addIngredientVariants(_ ingredients: [Ingredient]) {
        for ing in ingredients {
            let key = ing.name.lowercased()
            ingredientVariants[key, default: []].append(ing)
        }
    }
    
    /// Returns the next registered variant for `name`, advancing the round-robin index.
    /// Once all variants have been exhausted, the last variant is repeated (clamped index).
    /// - Parameter name: The ingredient name to look up (case-insensitive).
    /// - Returns: The next variant, or `nil` if no variants have been registered for this name.
    func getNextVariant(for name: String) -> Ingredient? {
        let key = name.lowercased()
        guard let variants = ingredientVariants[key], !variants.isEmpty else {
            return nil
        }
        
        let idx = ingredientFetchIndex[key, default: 0]
        let clamped = min(idx, variants.count - 1)
        ingredientFetchIndex[key] = idx + 1
        return variants[clamped]
    }
    
    /// Resets all registered variants and fetch indices.
    func clearVariants() {
        ingredientVariants.removeAll()
        ingredientFetchIndex.removeAll()
    }
    
    /// Returns the number of registered variants for the given name.
    /// - Parameter name: The ingredient name (case-insensitive).
    func variantsCount(for name: String) -> Int {
        let key = name.lowercased()
        return ingredientVariants[key]?.count ?? 0
    }
}