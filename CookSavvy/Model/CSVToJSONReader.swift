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
        case csvParsingFailed(Error)
        case zipExtractionFailed(Error)
        case emptyCSV
    }
    
    func parseCSVFromZip<T: Decodable>(zipURL: URL, csvFilename: String, useCache: Bool = true) throws -> [T] {
        let csvStr = try extractCSV(from: zipURL, with: csvFilename).data(using: .utf8)!
        let res = try! CSVDecoder().decode([T].self, from: csvStr)
        return res
//        let fm = FileManager.default
//        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let jsonURL = docsDir
//            .appendingPathComponent(csvFilename)
//            .replacingPathExtension(to: "json")
//        
//        let jsonData: Data
//        if !fm.fileExists(atPath: jsonURL.path) || !useCache {
//            let csvStr = try extractCSV(from: zipURL, with: csvFilename)
//            let csvAsDic = try csvToJSON(csvString: csvStr)
//            let csvAsJson = try JSONSerialization.data(withJSONObject: csvAsDic)
//            jsonData = csvAsJson
//            try csvAsJson.write(to: jsonURL)
//        } else {
//            jsonData = try Data(contentsOf: jsonURL)
//        }
//        
//        let result = try JSONDecoder().decode([T].self, from: jsonData)
//        return result
    }
    
    
//    private func csvToJSON(csvString: String) throws -> [[String:String]] {
//        let csv = try CSVReader(string: csvString, hasHeaderRow: true)
//        
//        guard let headers = csv.headerRow, !headers.isEmpty else {
//            throw ParserError.emptyCSV
//        }
//        
//        var res: [[String:String]] = []
//        while let values = csv.next() {
//            var dic: [String: String] = [:]
//            for (i, value) in values.enumerated() {
//                guard i < headers.count else { continue }
//                let key = headers[i]
//                if key.isEmpty { continue }
//                dic[key] = value
//            }
//            res.append(dic)
//        }
//        return res
//    }
    
    private func extractCSV(from zipFile: URL, with name: String) throws -> String {
        let unarch = Unarchiver()
        let csvData = try unarch.extract(file: name, fromZipFileUrl: zipFile)
        
        guard let csvString = String(data: csvData, encoding: .utf8) else {
            throw ParserError.csvParsingFailed(NSError(domain: "CSVToJSONReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode CSV data as UTF-8"]))
        }
        return csvString
    }
    
}

extension URL {
    func replacingPathExtension(to ext: String) -> URL {
        
        deletingPathExtension().appendingPathExtension(ext)
        
    }
}

// MARK: - CSVDecoder

/// A lightweight CSV decoder similar to `JSONDecoder`, built on top of the `CSV` library already in the project.
///
/// It decodes each CSV row into a `Decodable` type using the header row for keys.
/// Typical usage:
///
/// ```swift
/// let decoder = CSVDecoder()
/// let models: [MyModel] = try decoder.decode([MyModel].self, from: csvData)
/// // or from a String
/// let models: [MyModel] = try decoder.decode([MyModel].self, from: csvString)
/// ```
public struct CSVDecoder {
    // MARK: Configuration
    public enum DateDecodingStrategy {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        case iso8601
        case formatted(DateFormatter)
        case custom((Decoder) throws -> Date)
    }
    
    public enum DataDecodingStrategy {
        case deferredToData
        case base64
        case custom((Decoder) throws -> Data)
    }

    public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    public var dataDecodingStrategy: DataDecodingStrategy = .base64
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    // MARK: Public API
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV data is not valid UTF-8"))
        }
        return try decode(type, from: string)
    }

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        // Parse the CSV into an array of dictionaries keyed by header names
        let reader = try CSVReader(string: string, hasHeaderRow: true)
        guard let headers = reader.headerRow, !headers.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV has no header row"))
        }
        
        var rows: [[String: String]] = []
        while let values = reader.next() {
            var dict: [String: String] = [:]
            for (i, value) in values.enumerated() {
                guard i < headers.count else { continue }
                let key = headers[i]
                if key.isEmpty { continue }
                dict[key] = value
            }
            rows.append(dict)
        }

        let top = CSVTopLevelDecoder(rows: rows, options: makeOptions())
        return try T(from: top)
    }

    private func makeOptions() -> RowDecoder.Options {
        .init(dateStrategy: dateDecodingStrategy, dataStrategy: dataDecodingStrategy, userInfo: userInfo)
    }

    // MARK: RowDecoder
    private final class RowDecoder: Decoder {
        struct Options {
            let dateStrategy: CSVDecoder.DateDecodingStrategy
            let dataStrategy: CSVDecoder.DataDecodingStrategy
            let userInfo: [CodingUserInfoKey: Any]
        }

        let row: [String: String]
        let options: Options
        var codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey : Any] { options.userInfo }

        init(row: [String: String], options: Options, codingPath: [CodingKey] = []) {
            self.row = row
            self.options = options
            self.codingPath = codingPath
        }

        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            let container = KeyedContainer<Key>(decoder: self)
            return KeyedDecodingContainer(container)
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "CSV rows do not support unkeyed containers"))
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            throw DecodingError.typeMismatch(String.self, .init(codingPath: codingPath, debugDescription: "CSV rows do not support single value decoding at top-level"))
        }

        // MARK: KeyedContainer
        private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
            let decoder: RowDecoder
            var codingPath: [CodingKey] { decoder.codingPath }
            var allKeys: [Key] {
                decoder.row.keys.compactMap { Key(stringValue: $0) }
            }

            func contains(_ key: Key) -> Bool { decoder.row[key.stringValue] != nil }

            func decodeNil(forKey key: Key) throws -> Bool {
                guard let raw = decoder.row[key.stringValue] else { return true }
                return raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try decodeString(for: key).toBool() }
            func decode(_ type: String.Type, forKey key: Key) throws -> String { try decodeString(for: key) }
            func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try convert(decodeString(for: key), to: Double.self) }
            func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try convert(decodeString(for: key), to: Float.self) }
            func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try convert(decodeString(for: key), to: Int.self) }
            func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try convert(decodeString(for: key), to: Int8.self) }
            func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try convert(decodeString(for: key), to: Int16.self) }
            func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try convert(decodeString(for: key), to: Int32.self) }
            func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try convert(decodeString(for: key), to: Int64.self) }
            func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try convert(decodeString(for: key), to: UInt.self) }
            func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try convert(decodeString(for: key), to: UInt8.self) }
            func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try convert(decodeString(for: key), to: UInt16.self) }
            func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try convert(decodeString(for: key), to: UInt32.self) }
            func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try convert(decodeString(for: key), to: UInt64.self) }

            func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
                // If T is Decodable but not a primitive, attempt to decode using nested RowDecoder
                if T.self == Date.self || T.self == NSDate.self {
                    return try decodeDate(for: key) as! T
                } else if T.self == Data.self || T.self == NSData.self {
                    return try decodeData(for: key) as! T
                } else if T.self == URL.self || T.self == NSURL.self {
                    let s = try decodeString(for: key)
                    guard let url = URL(string: s) else {
                        throw DecodingError.dataCorrupted(.init(codingPath: codingPath + [key], debugDescription: "Invalid URL string: \(s)"))
                    }
                    return url as! T
                }

                // Nested/complex type: use same row and delegate
                let nested = RowDecoder(row: decoder.row, options: decoder.options, codingPath: codingPath + [key])
                return try T(from: nested)
            }

            func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? { try decodeOptional(for: key) { try decode(Bool.self, forKey: key) } }
            func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? { try decodeOptional(for: key) { try decode(String.self, forKey: key) } }
            func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? { try decodeOptional(for: key) { try decode(Double.self, forKey: key) } }
            func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? { try decodeOptional(for: key) { try decode(Float.self, forKey: key) } }
            func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? { try decodeOptional(for: key) { try decode(Int.self, forKey: key) } }
            func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? { try decodeOptional(for: key) { try decode(Int8.self, forKey: key) } }
            func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? { try decodeOptional(for: key) { try decode(Int16.self, forKey: key) } }
            func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? { try decodeOptional(for: key) { try decode(Int32.self, forKey: key) } }
            func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? { try decodeOptional(for: key) { try decode(Int64.self, forKey: key) } }
            func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? { try decodeOptional(for: key) { try decode(UInt.self, forKey: key) } }
            func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? { try decodeOptional(for: key) { try decode(UInt8.self, forKey: key) } }
            func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? { try decodeOptional(for: key) { try decode(UInt16.self, forKey: key) } }
            func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? { try decodeOptional(for: key) { try decode(UInt32.self, forKey: key) } }
            func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? { try decodeOptional(for: key) { try decode(UInt64.self, forKey: key) } }
            func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T : Decodable { try decodeOptional(for: key) { try decode(T.self, forKey: key) } }

            // Nested containers are not meaningful for CSV; provide placeholders
            func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
                let nested = RowDecoder(row: decoder.row, options: decoder.options, codingPath: codingPath + [key])
                return try nested.container(keyedBy: type)
            }
            func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { try decoder.unkeyedContainer() }
            func superDecoder() throws -> Decoder { RowDecoder(row: decoder.row, options: decoder.options, codingPath: codingPath) }
            func superDecoder(forKey key: Key) throws -> Decoder { RowDecoder(row: decoder.row, options: decoder.options, codingPath: codingPath + [key]) }

            // Helpers
            private func decodeString(for key: Key) throws -> String {
                guard let raw = decoder.row[key.stringValue] else {
                    throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing CSV column for key: \(key.stringValue)"))
                }
                return raw
            }

            private func decodeOptional<T>(for key: Key, _ body: () throws -> T) throws -> T? {
                guard let raw = decoder.row[key.stringValue] else { return nil }
                if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
                return try body()
            }

            private func decodeDate(for key: Key) throws -> Date {
                let s = try decodeString(for: key)
                switch decoder.options.dateStrategy {
                case .deferredToDate:
                    let nested = RowDecoder(row: [key.stringValue: s], options: decoder.options, codingPath: codingPath + [key])
                    return try Date(from: nested)
                case .secondsSince1970:
                    guard let seconds = TimeInterval(s) else { throw typeMismatch(Date.self, s, key) }
                    return Date(timeIntervalSince1970: seconds)
                case .millisecondsSince1970:
                    guard let ms = Double(s) else { throw typeMismatch(Date.self, s, key) }
                    return Date(timeIntervalSince1970: ms / 1000.0)
                case .iso8601:
                    #if compiler(>=5.1)
                    let formatter = ISO8601DateFormatter()
                    if let d = formatter.date(from: s) { return d }
                    #endif
                    throw typeMismatch(Date.self, s, key)
                case .formatted(let f):
                    if let d = f.date(from: s) { return d }
                    throw typeMismatch(Date.self, s, key)
                case .custom(let block):
                    let nested = RowDecoder(row: [key.stringValue: s], options: decoder.options, codingPath: codingPath + [key])
                    return try block(nested)
                }
            }

            private func decodeData(for key: Key) throws -> Data {
                let s = try decodeString(for: key)
                switch decoder.options.dataStrategy {
                case .deferredToData:
                    let nested = RowDecoder(row: [key.stringValue: s], options: decoder.options, codingPath: codingPath + [key])
                    return try Data(from: nested)
                case .base64:
                    guard let d = Data(base64Encoded: s) else { throw typeMismatch(Data.self, s, key) }
                    return d
                case .custom(let block):
                    let nested = RowDecoder(row: [key.stringValue: s], options: decoder.options, codingPath: codingPath + [key])
                    return try block(nested)
                }
            }

            private func convert<T: LosslessStringConvertible>(_ s: String, to: T.Type) throws -> T {
                if let v = T(s) { return v }
                throw DecodingError.typeMismatch(T.self, .init(codingPath: codingPath, debugDescription: "Cannot convert \(s) to \(T.self)"))
            }

            private func typeMismatch(_ t: Any.Type, _ raw: String, _ key: Key) -> DecodingError {
                DecodingError.typeMismatch(t, .init(codingPath: codingPath + [key], debugDescription: "Cannot convert value \"\(raw)\" to \(t)") )
            }
        }
    }
    
    // MARK: Top-level decoder and unkeyed container
    private final class CSVTopLevelDecoder: Decoder {
        let rows: [[String: String]]
        let options: RowDecoder.Options
        var codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey : Any] { options.userInfo }

        init(rows: [[String: String]], options: RowDecoder.Options) {
            self.rows = rows
            self.options = options
        }

        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            guard let first = rows.first else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV is empty; expected at least one data row"))
            }
            let rowDecoder = RowDecoder(row: first, options: options)
            return try rowDecoder.container(keyedBy: type)
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            return UnkeyedRowsContainer(rows: rows, options: options, codingPath: codingPath)
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            throw DecodingError.typeMismatch(String.self, .init(codingPath: codingPath, debugDescription: "CSV top-level does not support single value decoding"))
        }
    }

    private struct UnkeyedRowsContainer: UnkeyedDecodingContainer {
        let rows: [[String: String]]
        let options: RowDecoder.Options
        var codingPath: [CodingKey]
        var currentIndex: Int = 0

        var count: Int? { rows.count }
        var isAtEnd: Bool { currentIndex >= rows.count }

        mutating func decodeNil() throws -> Bool { false }

        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath, debugDescription: "Unkeyed container is at end"))
            }
            let row = rows[currentIndex]
            currentIndex += 1
            let d = RowDecoder(row: row, options: options)
            return try T(from: d)
        }

        // Primitive convenience implementations redirect to generic path
        mutating func decode(_ type: Bool.Type) throws -> Bool { try decode(Bool.self) }
        mutating func decode(_ type: String.Type) throws -> String { try decode(String.self) }
        mutating func decode(_ type: Double.Type) throws -> Double { try decode(Double.self) }
        mutating func decode(_ type: Float.Type) throws -> Float { try decode(Float.self) }
        mutating func decode(_ type: Int.Type) throws -> Int { try decode(Int.self) }
        mutating func decode(_ type: Int8.Type) throws -> Int8 { try decode(Int8.self) }
        mutating func decode(_ type: Int16.Type) throws -> Int16 { try decode(Int16.self) }
        mutating func decode(_ type: Int32.Type) throws -> Int32 { try decode(Int32.self) }
        mutating func decode(_ type: Int64.Type) throws -> Int64 { try decode(Int64.self) }
        mutating func decode(_ type: UInt.Type) throws -> UInt { try decode(UInt.self) }
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try decode(UInt8.self) }
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try decode(UInt16.self) }
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try decode(UInt32.self) }
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try decode(UInt64.self) }

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            let d = RowDecoder(row: rows[currentIndex], options: options)
            return try d.container(keyedBy: type)
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "CSV rows do not support nested unkeyed containers"))
        }

        mutating func superDecoder() throws -> Decoder {
            RowDecoder(row: rows[currentIndex], options: options)
        }
    }
}

// MARK: - Conversions
private extension String {
    func toBool() throws -> Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "true", "t", "yes", "y", "1": return true
        case "false", "f", "no", "n", "0": return false
        default:
            throw DecodingError.typeMismatch(Bool.self, .init(codingPath: [], debugDescription: "Cannot convert \(self) to Bool"))
        }
    }
}
