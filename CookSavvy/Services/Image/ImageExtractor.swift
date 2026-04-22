//
//  ImageExtractor.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation
import ZIPFoundation

/// Extracts image data from a ZIP archive, with optional disk-cache persistence.
///
/// Declared as an `actor` so concurrent extraction requests are serialised, preventing
/// duplicate reads from the same ZIP file when multiple images are requested simultaneously.
actor ImageExtractor {

    /// Extracts a single image from the ZIP archive by delegating to `extractImages(withNames:fromZipFile:useCache:)`.
    /// - Parameters:
    ///   - imageFileName: Filename of the image entry inside the ZIP.
    ///   - zipFileURL: URL of the ZIP archive.
    ///   - useCache: If `true`, serves from disk before extracting and writes the result to disk after extraction.
    /// - Returns: Raw image data for the requested file.
    /// - Throws: `Unarchiver.UnarchiverError.fileNotFoundInZipArchive` if the entry is missing.
    func extractImage(withName imageFileName: String, fromZipFile zipFileURL: URL, useCache: Bool = true) async throws -> Data {
        let result = try await extractImages(withNames: [imageFileName], fromZipFile: zipFileURL, useCache: useCache)
        guard let imageData = result[imageFileName] else {
            throw Unarchiver.UnarchiverError.fileNotFoundInZipArchive
        }
        return imageData
    }
    
    /// Extracts multiple images from a ZIP archive in a single pass, using disk cache to avoid redundant reads.
    ///
    /// First checks the Documents directory for each filename; only entries absent from disk are
    /// extracted from the ZIP via `Unarchiver`. Newly extracted data is written back to disk
    /// asynchronously so subsequent requests are served from cache.
    ///
    /// - Parameters:
    ///   - fileNames: Filenames of the image entries to extract.
    ///   - zipFileURL: URL of the ZIP archive.
    ///   - useCache: If `true`, serves from and writes to the Documents directory disk cache.
    /// - Returns: Dictionary mapping filename to raw image data; entries not found in the archive are omitted.
    func extractImages(withNames fileNames: [String], fromZipFile zipFileURL: URL, useCache: Bool = true) async throws -> [String: Data] {
        try await Task {
            let fileManager = FileManager.default
            let imagesDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            var extractedImages: [String: Data] = [:]
            var pendingFileNames: [String] = []
            
            // Check cache first
            for fileName in fileNames {
                let imageURL = imagesDirectory.appendingPathComponent(fileName)
                if useCache, fileManager.fileExists(atPath: imageURL.path) {
                    extractedImages[fileName] = try Data(contentsOf: imageURL)
                } else {
                    pendingFileNames.append(fileName)
                }
            }
            
            // Batch extract remaining files
            if !pendingFileNames.isEmpty {
                let unarchiver = Unarchiver()
                for fileName in pendingFileNames {
                    let imageData = try unarchiver.extract(file: fileName, fromZipFileUrl: zipFileURL)
                    extractedImages[fileName] = imageData
                    
                    // Cache asynchronously
                    if useCache {
                        Task {
                            let imageURL = imagesDirectory.appendingPathComponent(fileName)
                            try imageData.write(to: imageURL)
                        }
                    }
                }
            }
            
            return extractedImages
        }.value
    }
}
