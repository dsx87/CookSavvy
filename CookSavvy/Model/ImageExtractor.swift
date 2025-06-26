//
//  ImageExtractor.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation
import ZIPFoundation

final class ImageExtractor {
    private let prefix: String?
    
    init(prefix: String? = nil) {
        self.prefix = prefix
    }
    
    func extractImage(withName imageFileName: String, fromZipFile zipFileURL: URL, useCache: Bool = true) async throws -> Data {
        try await Task {
            let fm = FileManager.default
            let imagesDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            var imageFileName = imageFileName + ".jpg"
            if let prefix {
                imageFileName = prefix + imageFileName
            }
            let imageURL = imagesDir.appendingPathComponent(imageFileName)
            
            if useCache, fm.fileExists(atPath: imageURL.path) {
                return try Data(contentsOf: imageURL)
            }
            
            
            let unarc = Unarchiver()
            let imageData = try unarc.extract(file: imageFileName, fromZipFileUrl: zipFileURL)
            
            Task {
                if useCache {
                    try imageData.write(to: imageURL)
                }
            }
            
            return imageData
        }.value
    }
}
