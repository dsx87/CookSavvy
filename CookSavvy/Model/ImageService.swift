//
//  ImageService.swift
//  CookSavvy
//
//  Created by Cascade on 02/10/2025.
//

import Foundation
import UIKit

/// Service for loading and caching recipe and ingredient images
@MainActor
final class ImageService {
    
    // MARK: - Properties
    
    private let imageExtractor: ImageExtractor
    private let zipFileURL: URL?
    private let fileManager: FileManager
    private let imagesDirectory: URL
    
    /// In-memory cache for loaded images
    private var imageCache: [String: UIImage] = [:]
    
    /// Maximum number of images to keep in memory cache
    private let maxCacheSize: Int
    
    // MARK: - Initialization
    
    /// Initializes the image service
    /// - Parameters:
    ///   - imageExtractor: Actor for extracting images from ZIP
    ///   - zipFileURL: URL to the dataset ZIP file (optional, for extraction)
    ///   - maxCacheSize: Maximum number of images to cache in memory (default: 100)
    init(
        imageExtractor: ImageExtractor = ImageExtractor(),
        zipFileURL: URL? = nil,
        maxCacheSize: Int = 100
    ) {
        self.imageExtractor = imageExtractor
        self.maxCacheSize = maxCacheSize
        self.fileManager = FileManager.default
        self.imagesDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Find dataset ZIP if not provided
        if let providedURL = zipFileURL {
            self.zipFileURL = providedURL
        } else {
            self.zipFileURL = Bundle.main.url(
                forResource: "food-ingredients-and-recipe-dataset-with-images",
                withExtension: "zip"
            )
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads an image for a recipe
    /// - Parameter recipe: The recipe to load image for
    /// - Returns: UIImage if found, nil if not available
    func loadImage(for recipe: Recipe) async throws -> UIImage? {
        return try await loadImage(named: recipe.image)
    }
    
    /// Loads an image for an ingredient
    /// - Parameter ingredient: The ingredient to load image for
    /// - Returns: UIImage if found, nil if not available
    func loadImage(for ingredient: Ingredient) async throws -> UIImage? {
        guard let fileName = ingredient.pictureFileName else {
            return nil
        }
        return try await loadImage(named: fileName)
    }
    
    /// Loads an image by filename
    /// - Parameter fileName: The image filename
    /// - Returns: UIImage if found, nil if not available
    func loadImage(named fileName: String) async throws -> UIImage? {
        guard !fileName.isEmpty else {
            return nil
        }
        
        // Check memory cache first
        if let cached = imageCache[fileName] {
            return cached
        }
        
        // Try to load from disk cache (Documents directory)
        if let image = try await loadFromDisk(fileName: fileName) {
            cacheImage(image, forKey: fileName)
            return image
        }
        
        // Extract from ZIP if available
        if let zipURL = zipFileURL {
            if let image = try await extractFromZip(fileName: fileName, zipURL: zipURL) {
                cacheImage(image, forKey: fileName)
                return image
            }
        }
        
        // Image not found
        return nil
    }
    
    /// Loads images for multiple recipes in batch
    /// - Parameter recipes: Array of recipes
    /// - Returns: Dictionary mapping recipe IDs to UIImages
    func loadImages(for recipes: [Recipe]) async throws -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for recipe in recipes {
                group.addTask {
                    let image = try? await self.loadImage(for: recipe)
                    return (recipe.id, image)
                }
            }
            
            for await (id, image) in group {
                if let image = image {
                    result[id] = image
                }
            }
        }
        
        return result
    }
    
    /// Prefetches images for recipes (loads into cache without returning)
    /// - Parameter recipes: Array of recipes to prefetch images for
    func prefetchImages(for recipes: [Recipe]) async {
        await withTaskGroup(of: Void.self) { group in
            for recipe in recipes {
                group.addTask {
                    _ = try? await self.loadImage(for: recipe)
                }
            }
        }
    }
    
    /// Clears the in-memory image cache
    func clearCache() {
        imageCache.removeAll()
    }
    
    /// Clears images from disk cache
    /// - Parameter fileName: Optional specific file to clear, or nil to clear all
    func clearDiskCache(fileName: String? = nil) throws {
        if let fileName = fileName {
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } else {
            // Clear all cached images
            let contents = try fileManager.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents where fileURL.pathExtension.lowercased() == "png" || fileURL.pathExtension.lowercased() == "jpg" {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    /// Checks if an image exists in cache (memory or disk)
    /// - Parameter fileName: The image filename
    /// - Returns: True if image exists in cache
    func imageExists(named fileName: String) -> Bool {
        // Check memory cache
        if imageCache[fileName] != nil {
            return true
        }
        
        // Check disk cache
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Gets the number of images currently in memory cache
    var memoryCacheCount: Int {
        imageCache.count
    }
    
    // MARK: - Private Methods
    
    private func loadFromDisk(fileName: String) async throws -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        return UIImage(data: data)
    }
    
    private func extractFromZip(fileName: String, zipURL: URL) async throws -> UIImage? {
        do {
            let imageData = try await imageExtractor.extractImage(
                withName: fileName,
                fromZipFile: zipURL,
                useCache: true
            )
            return UIImage(data: imageData)
        } catch {
            // Image not found in ZIP or extraction failed
            return nil
        }
    }
    
    private func cacheImage(_ image: UIImage, forKey key: String) {
        // Enforce cache size limit
        if imageCache.count >= maxCacheSize {
            // Remove oldest entry (simple FIFO, could be improved with LRU)
            if let firstKey = imageCache.keys.first {
                imageCache.removeValue(forKey: firstKey)
            }
        }
        
        imageCache[key] = image
    }
}

// MARK: - Error Types

enum ImageServiceError: Error, LocalizedError {
    case imageNotFound(String)
    case invalidImageData(String)
    case diskAccessFailed(Error)
    case extractionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .imageNotFound(let fileName):
            return "Image '\(fileName)' not found"
        case .invalidImageData(let fileName):
            return "Invalid image data for '\(fileName)'"
        case .diskAccessFailed(let error):
            return "Disk access failed: \(error.localizedDescription)"
        case .extractionFailed(let error):
            return "Image extraction failed: \(error.localizedDescription)"
        }
    }
}
