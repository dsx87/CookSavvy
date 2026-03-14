//
//  RecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Represents the source from which recipes can be fetched
enum RecipeSourceType: String, Codable, CaseIterable {
    case offline = "Offline"
    case online = "Online"
    case ai = "AI"
    
    var displayName: String { rawValue }
    
    var iconName: String {
        switch self {
        case .offline: Icons.RecipeSource.offline
        case .online: Icons.RecipeSource.online
        case .ai: Icons.RecipeSource.ai
        }
    }
}

/// Protocol defining the interface for recipe sources
protocol RecipeSourceProtocol {
    /// The type of this source
    var sourceType: RecipeSourceType { get }
    
    /// Fetches recipes based on provided ingredients
    /// - Parameter ingredients: List of ingredients to search for
    /// - Returns: Array of matching recipes
    /// - Throws: Error if fetching fails
    func fetchRecipes(for ingredients: [Ingredient]) async throws -> [Recipe]
    
    /// Checks if the source is currently available
    /// - Returns: True if the source can be used, false otherwise
    func isAvailable() async -> Bool
}

extension RecipeSourceType {
    /// Filters `sources` down to those the user can actually access given their subscription.
    /// Falls back to `[.offline]` if all enabled sources are gated.
    static func accessible(
        from sources: Set<RecipeSourceType>,
        canAccessOnline: Bool,
        canAccessAI: Bool
    ) -> Set<RecipeSourceType> {
        var result = sources
        if result.contains(.online) && !canAccessOnline { result.remove(.online) }
        if result.contains(.ai) && !canAccessAI { result.remove(.ai) }
        return result.isEmpty ? [.offline] : result
    }

    /// Returns true when only the offline source is active, meaning the DB must be ready before querying.
    static func requiresDatabaseReady(_ sources: Set<RecipeSourceType>) -> Bool {
        sources == [.offline]
    }
}

/// Error types for recipe fetching operations
enum RecipeSourceError: Error, LocalizedError {
    case sourceUnavailable(RecipeSourceType)
    case noRecipesFound
    case networkError(Error)
    case invalidData
    case databaseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .sourceUnavailable(let type):
            return "Recipe source '\(type.displayName)' is currently unavailable"
        case .noRecipesFound:
            return "No recipes found for the provided ingredients"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data received from source"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}
