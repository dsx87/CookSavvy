//
//  ImageService.swift
//  CookSavvy
//
//  Created by Cascade on 02/10/2025.
//

import Foundation
import UIKit

/// LRU Cache wrapper for images
private class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private var keys = Set<String>()
    private let lock = NSLock()
    
    init(countLimit: Int, totalCostLimit: Int) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Approximate memory cost
        lock.lock()
        cache.setObject(image, forKey: key as NSString, cost: cost)
        keys.insert(key)
        lock.unlock()
    }
    
    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func removeAll() {
        lock.lock()
        cache.removeAllObjects()
        keys.removeAll()
        lock.unlock()
    }
    
    var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return keys.count
    }
}

/// Service for loading and caching recipe and ingredient images
final class ImageService {
    
    // MARK: - Properties
    
    private let imageExtractor: ImageExtractor
    private let zipFileURL: URL?
    private let fileManager: FileManager
    private let imagesDirectory: URL
    
    /// LRU in-memory cache for loaded images
    private let imageCache: ImageCache
    
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
        self.imageCache = ImageCache(countLimit: maxCacheSize, totalCostLimit: 50 * 1024 * 1024) // 50MB memory limit
        
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
        if let cached = imageCache.image(forKey: fileName) {
            return cached
        }
        
        // Try to load from disk cache (Documents directory)
        if let image = try await loadFromDisk(fileName: fileName) {
            imageCache.setImage(image, forKey: fileName)
            return image
        }
        
        // Extract from ZIP if available
        if let zipURL = zipFileURL {
            if let image = try await extractFromZip(fileName: fileName, zipURL: zipURL) {
                imageCache.setImage(image, forKey: fileName)
                return image
            }
        }
        
        // Image not found
        return nil
    }
    
    /// Loads images for multiple recipes in batch using optimized batch extraction
    /// - Parameter recipes: Array of recipes
    /// - Returns: Dictionary mapping recipe IDs to UIImages
    func loadImages(for recipes: [Recipe]) async throws -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        var uncachedImages: [(Recipe, String)] = []
        
        // Check memory cache first
        for recipe in recipes {
            if let cachedImage = imageCache.image(forKey: recipe.image) {
                result[recipe.id] = cachedImage
            } else {
                uncachedImages.append((recipe, recipe.image))
            }
        }
        
        // Batch extract uncached images
        if !uncachedImages.isEmpty, let zipURL = zipFileURL {
            let imageNames = uncachedImages.map { $0.1 }
            do {
                let imageDataDict = try await imageExtractor.extractImages(withNames: imageNames, fromZipFile: zipURL, useCache: true)
                
                for (recipe, imageName) in uncachedImages {
                    if let imageData = imageDataDict[imageName],
                       let image = UIImage(data: imageData) {
                        imageCache.setImage(image, forKey: imageName)
                        result[recipe.id] = image
                    }
                }
            } catch {
                // Images not found in ZIP - continue with empty/partial results
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
        if imageCache.image(forKey: fileName) != nil {
            return true
        }
        
        // Check disk cache
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Gets the number of images currently in memory cache
    var memoryCacheCount: Int {
        return imageCache.count
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
