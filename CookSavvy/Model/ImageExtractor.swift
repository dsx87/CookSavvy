//
//  ImageExtractor.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation
import ZIPFoundation

actor ImageExtractor {
    
    func extractImage(withName imageFileName: String, fromZipFile zipFileURL: URL, useCache: Bool = true) async throws -> Data {
        let result = try await extractImages(withNames: [imageFileName], fromZipFile: zipFileURL, useCache: useCache)
        guard let imageData = result[imageFileName] else {
            throw Unarchiver.UnarchiverError.fileNotFoundInZipArchive
        }
        return imageData
    }
    
    func extractImages(withNames fileNames: [String], fromZipFile zipFileURL: URL, useCache: Bool = true) async throws -> [String: Data] {
        try await Task {
            let fm = FileManager.default
            let imagesDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            var results: [String: Data] = [:]
            var filesToExtract: [String] = []
            
            // Check cache first
            for fileName in fileNames {
                let imageURL = imagesDir.appendingPathComponent(fileName)
                if useCache, fm.fileExists(atPath: imageURL.path) {
                    results[fileName] = try Data(contentsOf: imageURL)
                } else {
                    filesToExtract.append(fileName)
                }
            }
            
            // Batch extract remaining files
            if !filesToExtract.isEmpty {
                let unarc = Unarchiver()
                for fileName in filesToExtract {
                    let fileName = "Food Images/Food Images/\(fileName).jpg"
                    let imageData = try unarc.extract(file: fileName, fromZipFileUrl: zipFileURL)
                    results[fileName] = imageData
                    
                    // Cache asynchronously
                    if useCache {
                        Task {
                            let imageURL = imagesDir.appendingPathComponent(fileName)
                            try imageData.write(to: imageURL)
                        }
                    }
                }
            }
            
            return results
        }.value
    }
}
