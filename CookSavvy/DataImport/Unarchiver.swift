//
//  Unarchiver.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 27/06/2025.
//

import Foundation
import ZIPFoundation

final class Unarchiver {
    
    enum UnarchiverError: Error {
        case zipFileNotFound
        case fileNotFoundInZipArchive
        case fileNotExtracted
    }
    
    func extract(file filename: String, fromZipFileUrl zipUrl: URL) throws -> Data {
        let destinationURL = try extractAndSave(file: filename, fromZipFileUrl: zipUrl)
        let data = try Data(contentsOf: destinationURL)
        return data
    }
    
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
