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
        let fm = FileManager.default
        guard fm.fileExists(atPath: zipUrl.path) else {
            throw UnarchiverError.zipFileNotFound
        }
        
        let tmpDir = fm.temporaryDirectory
        
        let arch = try Archive(url: URL(filePath: zipUrl.path),
                               accessMode: .read)
        
        guard let entry = arch[filename] else {
            throw UnarchiverError.fileNotFoundInZipArchive
        }
        
        let dest = tmpDir.appendingPathComponent("tmp")
        
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        
        _ = try arch.extract(entry, to: dest)
        
        guard fm.fileExists(atPath: dest.path) else {
            throw UnarchiverError.fileNotExtracted
        }
        
        let data = try Data(contentsOf: dest)
        return data
    }
    
}
