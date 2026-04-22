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
    private let baseDirectory: URL
    private var recordsByHash: [String: ImageRecord] = [:]

    public init(baseDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("CookSavvyImageStore", isDirectory: true)) {
        self.baseDirectory = baseDirectory
    }

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

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func safeExtension(from filenameHint: String?) -> String {
        let ext = filenameHint.map { URL(fileURLWithPath: $0).pathExtension.lowercased() } ?? ""
        return ["png", "jpg", "jpeg", "heic", "webp"].contains(ext) ? ext : "bin"
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
    private let imageStore: ImageStore

    public init(imageStore: ImageStore = DefaultImageStore()) {
        self.imageStore = imageStore
    }

    public func canImport(_ url: URL) -> Bool {
        guard url.pathExtension.lowercased() == "zip",
              let archive = Archive(url: url, accessMode: .read) else {
            return false
        }
        return archive.contains { entry in
            entry.type == .file && entry.path.lowercased().hasSuffix(".csv")
        }
    }

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

    private func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }
}

// MARK: - ImportCoordinator

public protocol ImportCoordinator {
    func startImport(using importer: DatasetImporter, from url: URL) throws
}

public final class DefaultImportCoordinator: ImportCoordinator {
    public init() {}

    public func startImport(using importer: DatasetImporter, from url: URL) throws {
        guard importer.canImport(url) else {
            throw ImportError.invalidArchive
        }
        try importer.importAll(from: url, progress: nil, isCancelled: nil)
    }
}
