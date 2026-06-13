//
//  RecipeSource.swift
//  CookSavvy
//
//  Created by Cascade on 01/10/2025.
//

import Foundation

/// Represents the source from which recipes can be fetched
nonisolated enum RecipeSourceType: String, Codable, CaseIterable, Sendable {
    case offline = "Offline"
    case online = "Online"
    case ai = "AI"

    /// Human-readable label for display in the UI
    var displayName: String { rawValue }
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

/// Source-type utility helpers for entitlement and readiness decisions.
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
    /// The requested source type is not configured or not currently usable.
    case sourceUnavailable(RecipeSourceType)
    /// The source returned successfully but found no recipes matching the query.
    case noRecipesFound
    /// A network-level failure occurred while contacting a remote source.
    case networkError(Error)
    /// The remote source returned a response that could not be parsed.
    case invalidData
    /// A read or write operation against the local SQLite database failed.
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
