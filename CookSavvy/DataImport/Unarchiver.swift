//
//  Unarchiver.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 27/06/2025.
//

import Foundation
import ZIPFoundation

/// Extracts individual files from a ZIP archive using ZIPFoundation.
///
/// Stateless and `nonisolated`: its methods run synchronously on the caller's executor, so the
/// blocking ZIP/disk work stays off the main actor when invoked from the `ImageExtractor` actor
/// or from `DataImportService`'s `@concurrent` import path.
nonisolated final class Unarchiver {
    
    /// Errors thrown by ``Unarchiver`` operations.
    enum UnarchiverError: Error {
        /// The ZIP file does not exist at the given URL.
        case zipFileNotFound
        /// The ZIP archive does not contain an entry with the requested filename.
        case fileNotFoundInZipArchive
        /// The entry was found but could not be extracted to disk.
        case fileNotExtracted
    }
    
    /// Extracts a named file from a ZIP archive and returns its raw data.
    /// - Parameters:
    ///   - filename: The exact entry name inside the archive.
    ///   - zipUrl: The URL of the ZIP file.
    /// - Returns: The raw `Data` of the extracted file.
    /// - Throws: ``UnarchiverError`` if the archive or entry cannot be accessed.
    func extract(file filename: String, fromZipFileUrl zipUrl: URL) throws -> Data {
        let destinationURL = try extractAndSave(file: filename, fromZipFileUrl: zipUrl)
        let data = try Data(contentsOf: destinationURL)
        return data
    }
    
    /// Extracts a named file from a ZIP archive, saves it to the system's temporary directory,
    /// and returns its location on disk.
    ///
    /// Any existing file at the destination path is removed before extraction to prevent
    /// stale data from a prior run.
    ///
    /// - Parameters:
    ///   - filename: The exact entry name inside the archive.
    ///   - zipUrl: The URL of the ZIP file.
    /// - Returns: A `URL` pointing to the extracted file in the temporary directory.
    /// - Throws: ``UnarchiverError`` if the archive or entry cannot be accessed or extracted.
    func extractAndSave(file filename: String, fromZipFileUrl zipUrl: URL) throws -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: zipUrl.path) else {
            throw UnarchiverError.zipFileNotFound
        }
        
        let temporaryDirectory = fileManager.temporaryDirectory
        
        let archive = try Archive(url: URL(filePath: zipUrl.path),
                                  accessMode: .read)
        
        guard let entry = archive[filename] else {
            throw UnarchiverError.fileNotFoundInZipArchive
        }
        
        let destinationURL = temporaryDirectory.appendingPathComponent("tmp")
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        _ = try archive.extract(entry, to: destinationURL)
        
        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw UnarchiverError.fileNotExtracted
        }
        
        return destinationURL
    }
    
}
