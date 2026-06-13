import Foundation
import UIKit

/// Defines the public interface for image loading and caching.
///
/// Abstracts `ImageService` so view models and other consumers can be tested with a mock
/// that doesn't touch the filesystem or network.
nonisolated protocol ImageServiceProtocol: AnyObject, Sendable {
    /// Loads (or returns a cached) image for the given recipe.
    func loadImage(for recipe: Recipe) async throws -> UIImage?
    /// Loads (or returns a cached) image for the given ingredient.
    func loadImage(for ingredient: Ingredient) async throws -> UIImage?
    /// Loads an image by raw filename or URL string, checking cache tiers before fetching.
    func loadImage(named fileName: String) async throws -> UIImage?
    /// Loads images for multiple recipes in a single batched operation.
    /// - Returns: Dictionary mapping recipe ID to its loaded image; missing images are omitted.
    func loadImages(for recipes: [Recipe]) async throws -> [String: UIImage]
    /// Warms the cache for the given recipes without blocking the caller for results.
    func prefetchImages(for recipes: [Recipe]) async
    /// Evicts all images from the in-memory cache.
    func clearCache() async
    /// Removes cached image files from disk; pass `nil` to clear all cached images.
    func clearDiskCache(fileName: String?) async throws
    /// Returns `true` if the image is available in memory or disk cache without a network or ZIP fetch.
    func imageExists(named fileName: String) async -> Bool
    /// Number of images currently held in the in-memory cache.
    var memoryCacheCount: Int { get async }
}
