//
//  ImageService.swift
//  CookSavvy
//
//  Created by Cascade on 02/10/2025.
//

import Foundation
import UIKit
import CryptoKit

/// Internal constants that define cache sizing and dataset file naming conventions.
private enum ImageServiceConstants {
    static let bytesPerPixel = 4.0
    static let defaultCacheSize = 100
    static let memoryCacheLimit = 50 * 1024 * 1024
    static let datasetName = "food-ingredients-and-recipe-dataset-with-images"
    static let datasetExtension = "zip"
    static let pngExtension = "png"
    static let jpgExtension = "jpg"
    static let remoteSchemes = ["http://", "https://"]
}

/// In-memory image cache backed by `NSCache` with explicit byte-cost accounting.
///
/// Each image's cost is estimated as `width × height × 4 bytes` (RGBA). `NSCache` evicts
/// entries automatically under memory pressure. A separate `keys` set enables an O(1)
/// `count` property, since `NSCache` does not expose one directly.
private class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private var keys = Set<String>()
    private let lock = NSLock()
    
    /// Creates an image cache with explicit object count and memory-cost limits.
    init(countLimit: Int, totalCostLimit: Int) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }
    
    /// Stores `image` in the cache under `key`, using pixel-area cost for eviction weighting.
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * ImageServiceConstants.bytesPerPixel)
        lock.lock()
        cache.setObject(image, forKey: key as NSString, cost: cost)
        keys.insert(key)
        lock.unlock()
    }
    
    /// Returns the cached image for `key`, or `nil` if not present or already evicted.
    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    /// Evicts all images from the cache and clears the key tracking set.
    func removeAll() {
        lock.lock()
        cache.removeAllObjects()
        keys.removeAll()
        lock.unlock()
    }
    
    /// Maximum number of images the cache will hold before `NSCache` begins evicting entries.
    var countLimit: Int {
        get { cache.countLimit }
        set { cache.countLimit = newValue }
    }
    
    /// Approximate count of images tracked in the cache; may be slightly higher than actual if items were silently evicted by `NSCache`.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return keys.count
    }
}

/// Loads and caches recipe and ingredient images using a two-tier cache strategy.
///
/// **Cache hierarchy (checked in order):**
/// 1. In-memory `NSCache` — fastest path, automatically evicted under memory pressure.
/// 2. Disk cache — Documents directory, keyed by file name (local assets) or SHA-256 hash (remote URLs).
/// 3. ZIP extraction — extracts from the bundled dataset archive and writes to disk for future hits.
///
/// Remote URLs (`http`/`https`) are downloaded, persisted to disk under a SHA-256-derived filename,
/// and returned from the disk cache on all subsequent requests, avoiding redundant network calls.
final class ImageService: ImageServiceProtocol {
    
    // MARK: - Properties
    
    /// Extracts image data from the bundled dataset ZIP file.
    private let imageExtractor: ImageExtractor
    /// URL to the bundled dataset ZIP, used for extracting assets not yet on disk.
    private let zipFileURL: URL?
    /// Shared file-manager instance used for all disk I/O.
    private let fileManager: FileManager
    /// Root directory for the disk cache; maps to the app's Documents directory.
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
        maxCacheSize: Int = ImageServiceConstants.defaultCacheSize
    ) {
        self.imageExtractor = imageExtractor
        self.maxCacheSize = maxCacheSize
        self.fileManager = FileManager.default
        self.imagesDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.imageCache = ImageCache(countLimit: maxCacheSize, totalCostLimit: ImageServiceConstants.memoryCacheLimit)
        
        // Find dataset ZIP if not provided
        if let providedURL = zipFileURL {
            self.zipFileURL = providedURL
        } else {
            self.zipFileURL = Bundle.main.url(
                forResource: ImageServiceConstants.datasetName,
                withExtension: ImageServiceConstants.datasetExtension
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
        
        // TODO: think about separate method to handle online images
        if ImageServiceConstants.remoteSchemes.contains(where: fileName.hasPrefix) {
            return try await loadRemoteImage(urlString: fileName)
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
            for fileURL in contents where
                fileURL.pathExtension.lowercased() == ImageServiceConstants.pngExtension ||
                fileURL.pathExtension.lowercased() == ImageServiceConstants.jpgExtension {
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
    
    /// Reads an image from the disk cache (Documents directory) by file name.
    /// - Returns: The decoded image, or `nil` if no file exists at the expected path.
    private func loadFromDisk(fileName: String) async throws -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        return UIImage(data: data)
    }
    
    /// Downloads a remote image and caches it to disk under a deterministic SHA-256-derived filename.
    ///
    /// Checks memory and disk cache before issuing a network request. On a successful download,
    /// raw data is written to disk so the image is served from cache on all subsequent requests,
    /// avoiding redundant network calls.
    /// - Parameter urlString: An `http` or `https` URL string.
    /// - Returns: The downloaded image, or `nil` if the request fails or the URL is malformed.
    private func loadRemoteImage(urlString: String) async throws -> UIImage? {
        let cacheKey = Self.diskCacheKey(for: urlString)
        
        if let cached = imageCache.image(forKey: cacheKey) {
            return cached
        }
        
        if let diskImage = try await loadFromDisk(fileName: cacheKey) {
            imageCache.setImage(diskImage, forKey: cacheKey)
            return diskImage
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            return nil
        }
        
        let diskURL = imagesDirectory.appendingPathComponent(cacheKey)
        try? data.write(to: diskURL)
        imageCache.setImage(image, forKey: cacheKey)
        return image
    }
    
    /// Derives a stable disk-cache filename from a remote URL by SHA-256 hashing the URL string.
    ///
    /// The hash ensures the filename is filesystem-safe regardless of the original URL content,
    /// while still being deterministic — the same URL always maps to the same cache file.
    /// The original path extension is preserved (defaulting to `.jpg`) so the file can be
    /// decoded without additional metadata.
    /// - Parameter urlString: The remote image URL.
    /// - Returns: A hex-encoded SHA-256 digest with the original file extension appended.
    private static func diskCacheKey(for urlString: String) -> String {
        let hash = SHA256.hash(data: Data(urlString.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        let ext = URL(string: urlString)?.pathExtension.isEmpty == false
            ? "." + URL(string: urlString)!.pathExtension
            : "." + ImageServiceConstants.jpgExtension
        return hex + ext
    }
    
    /// Extracts a single image from the bundled dataset ZIP archive via `ImageExtractor`.
    /// - Parameters:
    ///   - fileName: The image filename to locate inside the archive.
    ///   - zipURL: URL of the ZIP archive to search.
    /// - Returns: The extracted image, or `nil` if the file is not found in the archive.
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

/// Errors thrown by `ImageService` operations.
enum ImageServiceError: Error, LocalizedError {
    /// No image could be located for the given filename in memory, disk cache, or the ZIP archive.
    case imageNotFound(String)
    /// A file was found but its data could not be decoded into a `UIImage`.
    case invalidImageData(String)
    /// A disk read or write operation (cache hit, write, or directory listing) failed.
    case diskAccessFailed(Error)
    /// Extracting image data from the bundled ZIP archive failed.
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
