//
//  DBTestHelpers.swift
//  CookSavvy
//
//  Created by Claude on 17/01/2026.
//

import Foundation

/// Helper class for test-specific database operations
/// This isolates test-specific code from production code
final class DBTestHelpers {
    
    /// Variant tracking for duplicate ingredient names (test-specific)
    private var ingredientVariants: [String: [Ingredient]] = [:]
    private var ingredientFetchIndex: [String: Int] = [:]
    
    /// Adds test variants for ingredients with duplicate names
    func addIngredientVariants(_ ingredients: [Ingredient]) {
        for ing in ingredients {
            let key = ing.name.lowercased()
            ingredientVariants[key, default: []].append(ing)
        }
    }
    
    /// Gets the next variant for testing purposes
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
    
    /// Clears all test variants
    func clearVariants() {
        ingredientVariants.removeAll()
        ingredientFetchIndex.removeAll()
    }
    
    /// Gets stored variants count for a name
    func variantsCount(for name: String) -> Int {
        let key = name.lowercased()
        return ingredientVariants[key]?.count ?? 0
    }
}