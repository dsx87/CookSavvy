//
//  CSVToJSONReader.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation
import ZIPFoundation
import CSV

/*
 Common usage:
 let csvConv = CSVToJSONReader()
 let zip = Bundle.main.url(forResource: "food-ingredients-and-recipe-dataset-with-images", withExtension: "zip")!
 let res:[Recipe] = try! csvConv.parseCSVFromZip(withURL: zip,
                                                 usingFilename: "Food Ingredients and Recipe Dataset with Image Name Mapping.csv")
 */

class CSVToJSONReader {
    enum ParserError: Error {
        case fileNotFound
    }
    
    func parseCSVFromZip<T: Decodable>(zipURL: URL, csvFilename: String, useCache: Bool = true) throws -> [T] {
        let fm = FileManager.default
        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let jsonURL = docsDir
            .appendingPathComponent(csvFilename)
            .replacingPathExtension(to: "json")
        
        let jsonData: Data
        if !fm.fileExists(atPath: jsonURL.path) || !useCache {
            guard let csvStr = extractCSV(from: zipURL, with: csvFilename) else {
                throw ParserError.fileNotFound
            }
            let csvAsDic = csvToJSON(csvString: csvStr)
            let csvAsJson = try JSONSerialization.data(withJSONObject: csvAsDic)
            jsonData = csvAsJson
            try csvAsJson.write(to: jsonURL)
        } else {
            jsonData = try Data(contentsOf: jsonURL)
        }
        
        let result = try JSONDecoder().decode([T].self, from: jsonData)
        return result
    }
    
    
    private func csvToJSON(csvString: String) -> [[String:String]] {
        do {
            let csv = try CSVReader(string: csvString, hasHeaderRow: true)
            
            var res: [[String:String]] = []
            let firstLine = csv.headerRow ?? []
            var dic: [String: String] = [:]
            while let csv = csv.next() {
                for (i, row) in csv.enumerated() {
                    let key = firstLine[i]
                    if key.isEmpty { continue }
                    dic[key] = row
                }
                res.append(dic)
            }
            return res
        } catch {
            print(error)
            return []
        }
        
    }
    
    private func extractCSV(from zipFile: URL, with name: String) -> String? {
        do {
            let unarch = Unarchiver()
            let csvData = try unarch.extract(file: name, fromZipFileUrl: zipFile)
            
            return String(data: csvData, encoding: .utf8)
        } catch {
            print(error)
            return nil
        }
    }
    
}

extension URL {
    func replacingPathExtension(to ext: String) -> URL {
        
        deletingPathExtension().appendingPathExtension(ext)
        
    }
}
