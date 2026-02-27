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
