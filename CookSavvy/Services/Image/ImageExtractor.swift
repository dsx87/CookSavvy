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

    private enum ImageExtractorError: Error {
        case documentsDirectoryUnavailable
    }

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
    /// so subsequent requests are served from cache.
    ///
    /// - Parameters:
    ///   - fileNames: Filenames of the image entries to extract.
    ///   - zipFileURL: URL of the ZIP archive.
    ///   - useCache: If `true`, serves from and writes to the Documents directory disk cache.
    /// - Returns: Dictionary mapping filename to raw image data; entries not found in the archive are omitted.
    func extractImages(withNames fileNames: [String], fromZipFile zipFileURL: URL, useCache: Bool = true) async throws -> [String: Data] {
        // Runs on this actor's executor (off the main actor); actor isolation serialises
        // concurrent extraction requests. The previous `try await Task { … }.value` wrapper
        // inherited this same executor and offloaded nothing, so it has been removed.
        let fileManager = FileManager.default
        guard let imagesDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ImageExtractorError.documentsDirectoryUnavailable
        }
        var extractedImages: [String: Data] = [:]
        var pendingFileNames: [String] = []

        // Treat disk-cache reads as an optimization. If a cached file is unreadable,
        // fall back to the ZIP entry so a stale or corrupt cache does not hide valid data.
        for fileName in fileNames {
            let imageURL = imagesDirectory.appendingPathComponent(fileName)
            if useCache, fileManager.fileExists(atPath: imageURL.path) {
                do {
                    extractedImages[fileName] = try Data(contentsOf: imageURL)
                } catch {
                    pendingFileNames.append(fileName)
                }
            } else {
                pendingFileNames.append(fileName)
            }
        }

        // Missing entries are skipped for batch extraction. Structural archive
        // failures still surface to callers because no useful partial result can be trusted.
        if !pendingFileNames.isEmpty {
            let unarchiver = Unarchiver()
            for fileName in pendingFileNames {
                let imageData: Data
                do {
                    imageData = try unarchiver.extract(file: fileName, fromZipFileUrl: zipFileURL)
                } catch Unarchiver.UnarchiverError.fileNotFoundInZipArchive {
                    continue
                }
                extractedImages[fileName] = imageData

                // Cache writes are best-effort; extraction success should still return image bytes.
                if useCache {
                    let imageURL = imagesDirectory.appendingPathComponent(fileName)
                    do {
                        try fileManager.createDirectory(
                            at: imageURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        try imageData.write(to: imageURL)
                    } catch {
                        continue
                    }
                }
            }
        }

        return extractedImages
    }
}
