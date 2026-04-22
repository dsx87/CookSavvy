//
//  DatasetImporting.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 01/09/2025.
//

import Foundation
import CoreGraphics
import CryptoKit
import UIKit
import ZIPFoundation

// MARK: - Shared types

/// Errors thrown during dataset import operations.
public enum ImportError: Error {
    case notImplemented
    case invalidArchive
    case cancelled
}

/// Identifies a stored image by its SHA-256 hash and its relative path within the image store.
public struct ImageRecord: Equatable {
    public let hash: String
    public let relativePath: String

    /// Creates a persisted image reference with its content hash and relative storage path.
    public init(hash: String, relativePath: String) {
        self.hash = hash
        self.relativePath = relativePath
    }
}

// MARK: - ImageStore

/// Protocol for persisting image data and generating thumbnails on demand.
public protocol ImageStore {
    /// Stores `data` and returns an ``ImageRecord`` describing where it was saved.
    /// If an identical image (same SHA-256) already exists, returns the existing record.
    func store(_ data: Data, filenameHint: String?) throws -> ImageRecord
    /// Returns a PNG thumbnail of the stored image at the given size.
    func thumbnail(for hash: String, size: CGSize) throws -> Data
}

/// File-backed ``ImageStore`` implementation that saves images into a local directory,
/// keyed by their SHA-256 hash to provide automatic deduplication.
public final class DefaultImageStore: ImageStore {
    private let baseDirectory: URL
    private var recordsByHash: [String: ImageRecord] = [:]

    /// Creates a file-backed store rooted at `baseDirectory`.
    public init(baseDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("CookSavvyImageStore", isDirectory: true)) {
        self.baseDirectory = baseDirectory
    }

    /// Stores the image data under a SHA-256-derived filename, returning an ``ImageRecord``.
    ///
    /// If an in-memory record for the same hash already exists the file write is skipped entirely.
    /// If the file does not yet exist on disk it is written atomically.
    public func store(_ data: Data, filenameHint: String?) throws -> ImageRecord {
        let hash = Self.sha256Hex(data)
        if let existing = recordsByHash[hash] {
            return existing
        }

        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let fileExtension = Self.safeExtension(from: filenameHint)
        let relativePath = "\(hash).\(fileExtension)"
        let destination = baseDirectory.appendingPathComponent(relativePath)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try data.write(to: destination, options: .atomic)
        }

        let record = ImageRecord(hash: hash, relativePath: relativePath)
        recordsByHash[hash] = record
        return record
    }

    /// Returns a down-scaled PNG of the stored image, or the original data if the image
    /// is already smaller than or equal to `size`.
    public func thumbnail(for hash: String, size: CGSize) throws -> Data {
        let data = try imageData(for: hash)
        guard size.width > 0,
              size.height > 0,
              let image = UIImage(data: data),
              image.size.width > 0,
              image.size.height > 0 else {
            return data
        }

        let scale = min(size.width / image.size.width, size.height / image.size.height, 1)
        guard scale < 1 else {
            return data
        }

        let targetSize = CGSize(
            width: max(floor(image.size.width * scale), 1),
            height: max(floor(image.size.height * scale), 1)
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: targetSize, format: format).pngData { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    /// Reads the original image bytes for a previously stored hash.
    /// Resolves from the in-memory cache first, then scans on-disk files by hash stem.
    private func imageData(for hash: String) throws -> Data {
        if let record = recordsByHash[hash] {
            return try Data(contentsOf: baseDirectory.appendingPathComponent(record.relativePath))
        }

        let contents = try FileManager.default.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil)
        guard let url = contents.first(where: { $0.deletingPathExtension().lastPathComponent == hash }) else {
            throw ImportError.invalidArchive
        }
        return try Data(contentsOf: url)
    }

    /// Computes a stable lowercase SHA-256 hex digest used as a content-addressed image id.
    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Restricts persisted extensions to a known safe set and falls back to `bin`.
    private static func safeExtension(from filenameHint: String?) -> String {
        let ext = filenameHint.map { URL(fileURLWithPath: $0).pathExtension.lowercased() } ?? ""
        return ["png", "jpg", "jpeg", "heic", "webp"].contains(ext) ? ext : "bin"
    }
}

// MARK: - DatasetImporter

/// Protocol for types that can import a dataset from a file URL.
public protocol DatasetImporter {
    /// Returns `true` if the importer can handle the file at the given URL.
    func canImport(_ url: URL) -> Bool
    /// Imports all supported entries from the file, reporting progress via `progress` (0–1)
    /// and honouring cancellation via `isCancelled`.
    func importAll(from url: URL,
                   progress: ((Double) -> Void)?,
                   isCancelled: (() -> Bool)?) throws
}

/// ``DatasetImporter`` that handles a ZIP archive containing a CSV file and an optional
/// images folder. Validates the archive, extracts CSV text (checked for UTF-8 validity),
/// and stores each image file via the injected ``ImageStore``.
public final class CSVZipAdapter: DatasetImporter {
    private let imageStore: ImageStore

    /// Creates an archive importer that delegates image persistence to `imageStore`.
    public init(imageStore: ImageStore = DefaultImageStore()) {
        self.imageStore = imageStore
    }

    /// Returns `true` only for ZIP archives that contain at least one CSV file entry.
    public func canImport(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "zip",
              let archive = Archive(url: url, accessMode: .read) else {
            return false
        }
        return archive.contains { entry in
            entry.type == .file && entry.path.lowercased().hasSuffix(".csv")
        }
    }

    /// Imports CSV and image entries from a ZIP archive while reporting linear progress.
    ///
    /// The import fails fast on cancellation, invalid archive structure, or invalid UTF-8 CSV payloads.
    public func importAll(from url: URL,
                           progress: ((Double) -> Void)?,
                           isCancelled: (() -> Bool)?) throws {
        guard url.pathExtension.lowercased() == "zip",
              let archive = Archive(url: url, accessMode: .read) else {
            throw ImportError.invalidArchive
        }

        let csvEntries = archive.filter { $0.type == .file && $0.path.lowercased().hasSuffix(".csv") }
        guard !csvEntries.isEmpty else {
            throw ImportError.invalidArchive
        }

        let imageEntries = archive.filter { entry in
            guard entry.type == .file else { return false }
            let lowercased = entry.path.lowercased()
            return lowercased.hasSuffix(".png")
                || lowercased.hasSuffix(".jpg")
                || lowercased.hasSuffix(".jpeg")
                || lowercased.hasSuffix(".heic")
                || lowercased.hasSuffix(".webp")
        }

        let entries = csvEntries + imageEntries
        let total = max(entries.count, 1)
        if isCancelled?() == true {
            throw ImportError.cancelled
        }
        progress?(0)

        for (index, entry) in entries.enumerated() {
            if isCancelled?() == true {
                throw ImportError.cancelled
            }

            let data = try extract(entry, from: archive)
            if entry.path.lowercased().hasSuffix(".csv") {
                guard String(data: data, encoding: .utf8)?.isEmpty == false else {
                    throw ImportError.invalidArchive
                }
            } else {
                _ = try imageStore.store(data, filenameHint: entry.path)
            }

            progress?(Double(index + 1) / Double(total))
        }
    }

    /// Extracts full entry data from the ZIP archive.
    private func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }
}

// MARK: - ImportCoordinator

/// Protocol for types that coordinate a full import run using a ``DatasetImporter``.
public protocol ImportCoordinator {
    /// Validates that `importer` can handle `url`, then delegates to ``DatasetImporter/importAll(from:progress:isCancelled:)``.
    func startImport(using importer: DatasetImporter, from url: URL) throws
}

/// Default ``ImportCoordinator`` that runs the import synchronously with no progress reporting or cancellation.
public final class DefaultImportCoordinator: ImportCoordinator {
    /// Creates a coordinator that runs imports synchronously.
    public init() {}

    /// Validates importer compatibility and then executes a full import pass.
    public func startImport(using importer: DatasetImporter, from url: URL) throws {
        guard importer.canImport(url) else {
            throw ImportError.invalidArchive
        }
        try importer.importAll(from: url, progress: nil, isCancelled: nil)
    }
}
