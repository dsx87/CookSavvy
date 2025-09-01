//
//  DatasetImporting.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 01/09/2025.
//

import Foundation
import CoreGraphics

// MARK: - Shared types

public enum ImportError: Error {
    case notImplemented
    case invalidArchive
    case cancelled
}

public struct ImageRecord: Equatable {
    public let hash: String
    public let relativePath: String

    public init(hash: String, relativePath: String) {
        self.hash = hash
        self.relativePath = relativePath
    }
}

// MARK: - ImageStore

public protocol ImageStore {
    func store(_ data: Data, filenameHint: String?) throws -> ImageRecord
    func thumbnail(for hash: String, size: CGSize) throws -> Data
}

public final class DefaultImageStore: ImageStore {
    public init() {}

    public func store(_ data: Data, filenameHint: String?) throws -> ImageRecord {
        throw ImportError.notImplemented
    }

    public func thumbnail(for hash: String, size: CGSize) throws -> Data {
        throw ImportError.notImplemented
    }
}

// MARK: - DatasetImporter

public protocol DatasetImporter {
    func canImport(_ url: URL) -> Bool
    func importAll(from url: URL,
                   progress: ((Double) -> Void)?,
                   isCancelled: (() -> Bool)?) throws
}

/// Adapter for a ZIP archive containing a CSV and images folder.
public final class CSVZipAdapter: DatasetImporter {
    public init() {}

    public func canImport(_ url: URL) -> Bool {
        // Stub
        return false
    }

    public func importAll(from url: URL,
                           progress: ((Double) -> Void)?,
                           isCancelled: (() -> Bool)?) throws {
        // Stub
        throw ImportError.notImplemented
    }
}

// MARK: - ImportCoordinator

public protocol ImportCoordinator {
    func startImport(using importer: DatasetImporter, from url: URL) throws
}

public final class DefaultImportCoordinator: ImportCoordinator {
    public init() {}

    public func startImport(using importer: DatasetImporter, from url: URL) throws {
        // Stub
        throw ImportError.notImplemented
    }
}
