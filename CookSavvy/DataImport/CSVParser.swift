//
//  CSVParser.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation
import ZIPFoundation
import CSV

final class CSVParser {
    enum ParserError: LocalizedError {
        case fileNotFound(String)
        case csvParsingFailed(Error)
        case zipExtractionFailed(Error)
        case emptyCSV

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "CSV file not found: \(filename)"
            case .csvParsingFailed(let error):
                return "Failed to parse CSV: \(error.localizedDescription)"
            case .zipExtractionFailed(let error):
                return "Failed to extract CSV from ZIP: \(error.localizedDescription)"
            case .emptyCSV:
                return "CSV file did not contain any rows"
            }
        }
    }

    func parseCSVFromZip<T: Decodable>(zipURL: URL, csvFilename: String) throws -> [T] {
        let csvString = try extractCSV(from: zipURL, with: csvFilename)

        do {
            let decodedItems = try CSVDecoder().decode([T].self, from: csvString)
            guard !decodedItems.isEmpty else {
                throw ParserError.emptyCSV
            }
            return decodedItems
        } catch let error as ParserError {
            throw error
        } catch {
            throw ParserError.csvParsingFailed(error)
        }
    }

    private func extractCSV(from zipFile: URL, with name: String) throws -> String {
        do {
            let csvData = try Unarchiver().extract(file: name, fromZipFileUrl: zipFile)

            guard let csvString = String(data: csvData, encoding: .utf8) else {
                throw ParserError.csvParsingFailed(
                    NSError(
                        domain: "CSVParser",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode CSV data as UTF-8"]
                    )
                )
            }

            return csvString
        } catch let error as ParserError {
            throw error
        } catch let error as Unarchiver.UnarchiverError {
            switch error {
            case .zipFileNotFound, .fileNotFoundInZipArchive:
                throw ParserError.fileNotFound(name)
            case .fileNotExtracted:
                throw ParserError.zipExtractionFailed(error)
            }
        } catch {
            throw ParserError.zipExtractionFailed(error)
        }
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
    private static let logger: any LoggerProtocol = LoggingService().makeLogger(category: .csvParser)

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

    public func decode<T: Decodable>(_ type: [T].Type, from data: Data) throws -> [T] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV data is not valid UTF-8"))
        }
        return try decode(type, from: string)
    }

    public func decode<T: Decodable>(_ type: [T].Type, from string: String) throws -> [T] {
        let reader = try CSVReader(string: string, hasHeaderRow: true)
        guard let headers = reader.headerRow, !headers.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV has no header row"))
        }

        var decodedRows: [T] = []
        var rowNumber = 1
        while let values = reader.next() {
            rowNumber += 1
            let row = makeRow(headers: headers, values: values)
            let decoder = RowDecoder(row: row, options: makeOptions())
            do {
                decodedRows.append(try T(from: decoder))
            } catch {
                Self.logger.warning("Skipping malformed CSV row \(rowNumber): \(error.localizedDescription)")
            }
        }

        return decodedRows
    }

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let reader = try CSVReader(string: string, hasHeaderRow: true)
        guard let headers = reader.headerRow, !headers.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV has no header row"))
        }
        
        var rows: [[String: String]] = []
        while let values = reader.next() {
            rows.append(makeRow(headers: headers, values: values))
        }

        let top = CSVTopLevelDecoder(rows: rows, options: makeOptions())
        return try T(from: top)
    }

    private func makeOptions() -> RowDecoder.Options {
        .init(dateStrategy: dateDecodingStrategy, dataStrategy: dataDecodingStrategy, userInfo: userInfo)
    }

    private func makeRow(headers: [String], values: [String]) -> [String: String] {
        var row: [String: String] = [:]
        for (index, value) in values.enumerated() {
            guard index < headers.count else { continue }
            let key = headers[index]
            if key.isEmpty { continue }
            row[key] = value
        }
        return row
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

            func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try decodeBool(for: key) }
            func decode(_ type: String.Type, forKey key: Key) throws -> String { try decodeString(for: key) }
            func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try convert(trimmedString(for: key), to: Double.self, key: key) }
            func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try convert(trimmedString(for: key), to: Float.self, key: key) }
            func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try convert(trimmedString(for: key), to: Int.self, key: key) }
            func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try convert(trimmedString(for: key), to: Int8.self, key: key) }
            func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try convert(trimmedString(for: key), to: Int16.self, key: key) }
            func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try convert(trimmedString(for: key), to: Int32.self, key: key) }
            func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try convert(trimmedString(for: key), to: Int64.self, key: key) }
            func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try convert(trimmedString(for: key), to: UInt.self, key: key) }
            func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try convert(trimmedString(for: key), to: UInt8.self, key: key) }
            func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try convert(trimmedString(for: key), to: UInt16.self, key: key) }
            func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try convert(trimmedString(for: key), to: UInt32.self, key: key) }
            func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try convert(trimmedString(for: key), to: UInt64.self, key: key) }

            func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
                // If T is Decodable but not a primitive, attempt to decode using nested RowDecoder
                if T.self == Date.self {
                    return try castDecodedValue(decodeDate(for: key), to: T.self, key: key)
                } else if T.self == NSDate.self {
                    return try castDecodedValue(decodeDate(for: key) as NSDate, to: T.self, key: key)
                } else if T.self == Data.self {
                    return try castDecodedValue(decodeData(for: key), to: T.self, key: key)
                } else if T.self == NSData.self {
                    return try castDecodedValue(decodeData(for: key) as NSData, to: T.self, key: key)
                } else if T.self == URL.self {
                    let s = try trimmedString(for: key)
                    guard let url = URL(string: s) else {
                        throw DecodingError.dataCorrupted(.init(codingPath: codingPath + [key], debugDescription: "Invalid URL string: \(s)"))
                    }
                    return try castDecodedValue(url, to: T.self, key: key)
                } else if T.self == NSURL.self {
                    let s = try trimmedString(for: key)
                    guard let url = NSURL(string: s) else {
                        throw DecodingError.dataCorrupted(.init(codingPath: codingPath + [key], debugDescription: "Invalid URL string: \(s)"))
                    }
                    return try castDecodedValue(url, to: T.self, key: key)
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

            private func trimmedString(for key: Key) throws -> String {
                try decodeString(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            private func decodeBool(for key: Key) throws -> Bool {
                let value = try trimmedString(for: key).lowercased()
                switch value {
                case "true", "t", "yes", "y", "1":
                    return true
                case "false", "f", "no", "n", "0":
                    return false
                default:
                    throw typeMismatch(Bool.self, value, key)
                }
            }

            private func decodeDate(for key: Key) throws -> Date {
                let s = try trimmedString(for: key)
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
                let s = try trimmedString(for: key)
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

            private func convert<T: LosslessStringConvertible>(_ s: String, to: T.Type, key: Key) throws -> T {
                if let v = T(s) { return v }
                throw typeMismatch(T.self, s, key)
            }

            private func typeMismatch(_ t: Any.Type, _ raw: String, _ key: Key) -> DecodingError {
                DecodingError.typeMismatch(t, .init(codingPath: codingPath + [key], debugDescription: "Cannot convert value \"\(raw)\" to \(t)") )
            }

            private func castDecodedValue<T, Value>(_ value: Value, to type: T.Type, key: Key) throws -> T {
                guard let typedValue = value as? T else {
                    throw DecodingError.typeMismatch(
                        T.self,
                        .init(codingPath: codingPath + [key], debugDescription: "Decoded value cannot be represented as \(T.self)")
                    )
                }
                return typedValue
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

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            let d = RowDecoder(row: try currentRow(), options: options)
            return try d.container(keyedBy: type)
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "CSV rows do not support nested unkeyed containers"))
        }

        mutating func superDecoder() throws -> Decoder {
            RowDecoder(row: try currentRow(), options: options)
        }

        private func currentRow() throws -> [String: String] {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(
                    [String: String].self,
                    .init(codingPath: codingPath, debugDescription: "Unkeyed container is at end")
                )
            }
            return rows[currentIndex]
        }
    }
}
