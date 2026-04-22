//
//  CSVParser.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 30/04/2025.
//

import Foundation
import ZIPFoundation
import CSV

/// Thin wrapper around ``CSVDecoder`` that reads a named CSV file from inside a ZIP archive
/// and returns an array of the given `Decodable` type.
///
/// Used by ``DataImportService`` to seed the local database from the bundled dataset ZIP.
final class CSVParser {
    /// Errors thrown during CSV extraction or parsing.
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

    /// Extracts `csvFilename` from the ZIP at `zipURL` and decodes every row into `T`.
    /// - Parameters:
    ///   - zipURL: URL of the ZIP archive bundled in the app.
    ///   - csvFilename: The exact entry name of the CSV file inside the archive.
    /// - Returns: An array of decoded `T` values, one per data row.
    /// - Throws: ``ParserError`` if the file cannot be found, extracted, or parsed.
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

    /// Extracts the named CSV file from a ZIP archive and returns its contents as a UTF-8 string.
    /// Maps ``Unarchiver/UnarchiverError`` cases to the appropriate ``ParserError``.
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
    /// Strategy used to decode `Date` values from CSV string cells.
    public enum DateDecodingStrategy {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        case iso8601
        case formatted(DateFormatter)
        case custom((Decoder) throws -> Date)
    }
    
    /// Strategy used to decode `Data` values from CSV string cells.
    public enum DataDecodingStrategy {
        case deferredToData
        case base64
        case custom((Decoder) throws -> Data)
    }

    public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    public var dataDecodingStrategy: DataDecodingStrategy = .base64
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// Creates a decoder configured with default date/data strategies.
    public init() {}

    // MARK: Public API
    /// Decodes a single `T` from UTF-8 CSV `Data`, treating the first row as a header.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV data is not valid UTF-8"))
        }
        return try decode(type, from: string)
    }

    /// Decodes an array of `T` from UTF-8 CSV `Data`, treating the first row as a header.
    public func decode<T: Decodable>(_ type: [T].Type, from data: Data) throws -> [T] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV data is not valid UTF-8"))
        }
        return try decode(type, from: string)
    }

    /// Decodes an array of `T` from a CSV string.
    ///
    /// Iterates each data row, maps header columns to values, and decodes each row via
    /// `RowDecoder`. Malformed rows are skipped with a warning log rather than aborting
    /// the entire import — a deliberate trade-off for datasets with occasional dirty data.
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

    /// Decodes a single `T` from a CSV string via ``CSVTopLevelDecoder``.
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

    /// Builds immutable per-row options from the decoder's current strategy configuration.
    private func makeOptions() -> RowDecoder.Options {
        .init(dateStrategy: dateDecodingStrategy, dataStrategy: dataDecodingStrategy, userInfo: userInfo)
    }

    /// Zips header names with row values, discarding overflow values and empty header keys.
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
    /// `Decoder` implementation for a single CSV row represented as `[String: String]`.
    ///
    /// The CSV format is inherently flat so unkeyed and single-value containers are not supported
    /// at the top level. Nested `Decodable` types are decoded by passing the same row dictionary
    /// down, allowing Swift's synthesised `init(from:)` to read nested key paths as flat column names.
    private final class RowDecoder: Decoder {
    /// Captures per-row decoding strategies inherited from the parent ``CSVDecoder``.
        struct Options {
            let dateStrategy: CSVDecoder.DateDecodingStrategy
            let dataStrategy: CSVDecoder.DataDecodingStrategy
            let userInfo: [CodingUserInfoKey: Any]
        }

        let row: [String: String]
        let options: Options
        var codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey : Any] { options.userInfo }

        /// Creates a decoder for a single flat CSV row dictionary.
        init(row: [String: String], options: Options, codingPath: [CodingKey] = []) {
            self.row = row
            self.options = options
            self.codingPath = codingPath
        }

        /// Returns a keyed container backed by the current row map.
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            let container = KeyedContainer<Key>(decoder: self)
            return KeyedDecodingContainer(container)
        }

        /// CSV rows are flat key/value maps and cannot be decoded as arrays.
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "CSV rows do not support unkeyed containers"))
        }

        /// CSV rows do not expose a meaningful top-level scalar representation.
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            throw DecodingError.typeMismatch(String.self, .init(codingPath: codingPath, debugDescription: "CSV rows do not support single value decoding at top-level"))
        }

        // MARK: KeyedContainer
        /// Keyed view over a single CSV row, mapping header names to decoding keys.
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

            /// Decodes complex `Decodable` values and special Foundation bridge types.
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
            /// Creates a nested keyed container by reusing the same row context.
            func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
                let nested = RowDecoder(row: decoder.row, options: decoder.options, codingPath: codingPath + [key])
                return try nested.container(keyedBy: type)
            }
            func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { try decoder.unkeyedContainer() }
            func superDecoder() throws -> Decoder { RowDecoder(row: decoder.row, options: decoder.options, codingPath: codingPath) }
            func superDecoder(forKey key: Key) throws -> Decoder { RowDecoder(row: decoder.row, options: decoder.options, codingPath: codingPath + [key]) }

            // Helpers
            /// Returns the raw cell value for a key or throws a missing-column error.
            private func decodeString(for key: Key) throws -> String {
                guard let raw = decoder.row[key.stringValue] else {
                    throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing CSV column for key: \(key.stringValue)"))
                }
                return raw
            }

            /// Applies optional semantics where absent or empty cells are treated as `nil`.
            private func decodeOptional<T>(for key: Key, _ body: () throws -> T) throws -> T? {
                guard let raw = decoder.row[key.stringValue] else { return nil }
                if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
                return try body()
            }

            /// Reads a value and trims surrounding whitespace/newline characters.
            private func trimmedString(for key: Key) throws -> String {
                try decodeString(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            /// Accepts common boolean literals used in CSV exports.
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

            /// Decodes a `Date` according to the configured ``DateDecodingStrategy``.
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

            /// Decodes binary data according to the configured ``DataDecodingStrategy``.
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

            /// Converts a scalar string using a `LosslessStringConvertible` target type.
            private func convert<T: LosslessStringConvertible>(_ s: String, to: T.Type, key: Key) throws -> T {
                if let v = T(s) { return v }
                throw typeMismatch(T.self, s, key)
            }

            /// Builds a standardized type-mismatch error at the current key path.
            private func typeMismatch(_ t: Any.Type, _ raw: String, _ key: Key) -> DecodingError {
                DecodingError.typeMismatch(t, .init(codingPath: codingPath + [key], debugDescription: "Cannot convert value \"\(raw)\" to \(t)") )
            }

            /// Safely downcasts an intermediate decoded value to the requested generic output type.
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
    /// Top-level `Decoder` that holds all parsed rows and dispatches to either a keyed container
    /// (single-row decode) or an unkeyed container (array decode).
    private final class CSVTopLevelDecoder: Decoder {
        let rows: [[String: String]]
        let options: RowDecoder.Options
        var codingPath: [CodingKey] = []
        var userInfo: [CodingUserInfoKey : Any] { options.userInfo }

        /// Creates a decoder representing all parsed CSV rows.
        init(rows: [[String: String]], options: RowDecoder.Options) {
            self.rows = rows
            self.options = options
        }

        /// Decodes a keyed value from the first data row.
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            guard let first = rows.first else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "CSV is empty; expected at least one data row"))
            }
            let rowDecoder = RowDecoder(row: first, options: options)
            return try rowDecoder.container(keyedBy: type)
        }

        /// Returns an unkeyed container for array-style decoding across all rows.
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            return UnkeyedRowsContainer(rows: rows, options: options, codingPath: codingPath)
        }

        /// CSV top-level decoding does not support single scalar values.
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            throw DecodingError.typeMismatch(String.self, .init(codingPath: codingPath, debugDescription: "CSV top-level does not support single value decoding"))
        }
    }

    /// `UnkeyedDecodingContainer` that iterates over all parsed CSV rows, decoding each one
    /// via ``RowDecoder`` on each call to `decode(_:)`.
    private struct UnkeyedRowsContainer: UnkeyedDecodingContainer {
        let rows: [[String: String]]
        let options: RowDecoder.Options
        var codingPath: [CodingKey]
        var currentIndex: Int = 0

        var count: Int? { rows.count }
        var isAtEnd: Bool { currentIndex >= rows.count }

        /// CSV rows always represent objects, so `nil` is never emitted here.
        mutating func decodeNil() throws -> Bool { false }

        /// Decodes the next row as `T`, advancing the container index.
        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath, debugDescription: "Unkeyed container is at end"))
            }
            let row = rows[currentIndex]
            currentIndex += 1
            let d = RowDecoder(row: row, options: options)
            return try T(from: d)
        }

        /// Decodes the current row as a nested keyed container.
        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            let d = RowDecoder(row: try currentRow(), options: options)
            return try d.container(keyedBy: type)
        }

        /// Nested unkeyed containers are unsupported because rows are flat.
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            throw DecodingError.typeMismatch([Any].self, .init(codingPath: codingPath, debugDescription: "CSV rows do not support nested unkeyed containers"))
        }

        /// Returns a decoder for the current row without advancing the index.
        mutating func superDecoder() throws -> Decoder {
            RowDecoder(row: try currentRow(), options: options)
        }

        /// Returns the row at `currentIndex` or throws when the container is exhausted.
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
