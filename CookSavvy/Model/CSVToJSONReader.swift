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
    
    
    //    enum ConverterError: Error {
    //        case noColumns
    //    }
    //
    //    enum Column: Equatable {
    //        case simple(title: String)
    //        case complex(title: String, separator: Character)
    //    }
    //
    //    private let columns: [Column]
    //    private let ignoredColumns: [Column]
    //    private let simpleSeparator: Character
    //    init(columns: [Column], separator: Character, ignoredColumns: [Column] = []) {
    //        self.columns = columns
    //        self.simpleSeparator = separator
    //        self.ignoredColumns = ignoredColumns
    //    }
    
    //    convenience init() {
    //        self.init(columns: [
    //            .simple(title: "index"),
    //            .simple(title: "title"),
    //            .complex(title: "ingredients", separator: "\""),
    //            .complex(title: "instructions", separator: "\""),
    //            .simple(title: "image"),
    //            .complex(title: "cleanedIngredients", separator: "\"")
    //        ],
    //                  separator: ",",
    //                  ignoredColumns: [.simple(title: "index")]
    //        )
    //    }
    
    
    //    private func createColumnDic() -> [String:String] {
    //        columns.reduce(into: [:]) { partialResult, col in
    //            guard !ignoredColumns.contains(col) else { return }
    //            switch col {
    //            case .simple(let title):
    //                partialResult[title] = ""
    //            case .complex(let title, _):
    //                partialResult[title] = ""
    //            }
    //        }
    //    }
    //    func csvToJSON(csvString: String) throws(ConverterError) -> Data? {
    //        guard !columns.isEmpty else {
    //            throw .noColumns
    //        }
    //        let winEndline = "\r\n"
    //        let unixEndline = "\n"
    //        guard let range = csvString.range(of: winEndline) ?? csvString.range(of: unixEndline) else {
    //            return nil
    //        }
    //        var currentIndex = range.upperBound
    //
    //        var dic = createColumnDic()
    //
    //        var currentColumn = columns.first
    //
    //        var result: [[String: String]] = []
    //
    //        while currentIndex < csvString.endIndex {
    //            guard let currentCol = currentColumn else {
    //                result.append(dic)
    //                dic = createColumnDic()
    //                currentColumn = columns.first
    //                continue
    //            }
    //
    //            switch currentCol {
    //            case .simple(let title):
    //                let range = csvString.rangeOfCharacter(from: .init(charactersIn: String(simpleSeparator)), range: currentIndex..<csvString.endIndex)
    //                if !ignoredColumns.contains(currentCol) {
    //                    dic[title]?.append(contentsOf: csvString[currentIndex..<range!.lowerBound])
    //                }
    //                currentColumn = columns.next(from: currentCol)
    //                currentIndex = range!.upperBound
    //                continue
    //            case .complex(let title, let complexSeparator):
    //                let isLast = columns.last == currentCol
    //
    //                let separatorStr = "\(complexSeparator)\(isLast ? winEndline : String(simpleSeparator))"
    //                let range = csvString.range(of: separatorStr, range: currentIndex..<csvString.endIndex)
    //
    //                if !ignoredColumns.contains(currentCol) {
    //                    dic[title]?.append(contentsOf: csvString[currentIndex..<range!.lowerBound])
    //                }
    //                currentIndex = range!.upperBound
    //                currentColumn = columns.next(from: currentCol)
    //            }
    //
    //        }
    //
    //        let data = try? JSONSerialization.data(withJSONObject: result)
    //        return data
    //
    //    }
    
    
    
}

extension URL {
    func replacingPathExtension(to ext: String) -> URL {
        
        deletingPathExtension().appendingPathExtension(ext)
        
    }
}

//extension String {
//    subscript(safePrev currentIndex: Index) -> Character? {
//        guard currentIndex != self.startIndex else {
//            return nil
//        }
//        return self[self.index(before: currentIndex)]
//    }
//
//    subscript(safeNext currentIndex: Index) -> Character? {
//        guard currentIndex != self.index(before: self.endIndex) else {
//            return nil
//        }
//        return self[self.index(after: currentIndex)]
//    }
//
//    mutating func appendChar(_ char: Character) {
//        self.append(String(char))
//    }
//}
//
//extension Array where Element == CSVToJSONConverter.Column {
//    func next(from element: Element) -> Element? {
//        guard let currentIndex = self.firstIndex(of: element),
//              currentIndex < self.index(before: self.endIndex)
//        else { return nil }
//        let nextIndex = self.index(after: currentIndex)
//        return self[nextIndex]
//    }
//}
