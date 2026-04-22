//
//  DatasetImportingTests.swift
//  CookSavvyTests
//
//  Created by Igor Pivnyk on 01/09/2025.
//

import XCTest
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import CookSavvy

// MARK: - Helpers shared across importer tests
private enum ImportTestHelpers {
    static func temporaryDirectory(testName: String = UUID().uuidString) throws -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("CookSavvyTests_\(testName)_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Makes a minimal CSV content matching the current dataset idea
    /// Columns: title,image,ingredients,instructions
    static func makeMiniCSV(rows: Int = 3) -> String {
        var csv = "title,image,ingredients,instructions\n"
        for i in 1...rows {
            let title = "Recipe_\(i)"
            let image = "img_\(i).png"
            let ingredients = "Salt|Pepper|Olive Oil"
            let instructions = "Step 1|Step 2|Step 3"
            csv += "\(title),\(image),\(ingredients),\(instructions)\n"
        }
        return csv
    }

    /// Creates a small solid-color PNG image in memory
    static func makePNG(width: Int = 8, height: Int = 8, color: CGColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1)) throws -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let alphaInfo = CGImageAlphaInfo.premultipliedLast
        guard let ctx = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0, // let CG decide
                                  space: cs,
                                  bitmapInfo: alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw NSError(domain: "makePNG", code: 1)
        }
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cg = ctx.makeImage() else { throw NSError(domain: "makePNG", code: 2) }

        let out = CFDataCreateMutable(nil, 0)!
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    /// Build a tiny ZIP with one CSV and N images
    /// The ZIP layout will be:
    /// - dataset.csv
    /// - images/img_1.png ... images/img_N.png
    static func makeMiniDatasetZip(rows: Int = 3, csvName: String = "dataset.csv") throws -> URL {
        let fm = FileManager.default
        let dir = try temporaryDirectory(testName: "mini_zip_\(rows)")
        let zipURL = dir.appendingPathComponent("dataset.zip")

        // Create a temp folder structure first
        let work = dir.appendingPathComponent("work", isDirectory: true)
        let images = work.appendingPathComponent("images", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        try fm.createDirectory(at: images, withIntermediateDirectories: true)

        // Write CSV
        let csv = makeMiniCSV(rows: rows)
        try csv.data(using: .utf8)!.write(to: work.appendingPathComponent(csvName))

        // Write PNGs
        for i in 1...rows {
            let data = try makePNG(color: CGColor(red: CGFloat(i % 2), green: 0.5, blue: 0.2, alpha: 1))
            try data.write(to: images.appendingPathComponent("img_\(i).png"))
        }
        
        try fm.zipItem(at: work, to: zipURL)
        return zipURL
        
    }
}

// (no helper needed; we create CFMutableData directly in makePNG)

// MARK: - Entity: DatasetImporter (contract/spec tests)
final class DatasetImporterTests: XCTestCase {
    func testImporterCanDetectSupportedArchive() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 1)
        let importer = CSVZipAdapter()
        XCTAssertTrue(importer.canImport(zip))
    }

    func testImporterRejectsNonZipArchive() throws {
        let dir = try ImportTestHelpers.temporaryDirectory(testName: "invalid_archive")
        let url = dir.appendingPathComponent("dataset.txt")
        try Data("not a zip".utf8).write(to: url)

        let importer = CSVZipAdapter()
        XCTAssertFalse(importer.canImport(url))
        XCTAssertThrowsError(try importer.importAll(from: url, progress: nil, isCancelled: nil))
    }

    func testImporterPerformsFullImportWithProgress() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 4)
        let importer = CSVZipAdapter(
            imageStore: DefaultImageStore(baseDirectory: try ImportTestHelpers.temporaryDirectory(testName: "image_store"))
        )
        var progressValues: [Double] = []

        try importer.importAll(from: zip, progress: { progressValues.append($0) }, isCancelled: { false })

        XCTAssertEqual(progressValues.first, 0)
        XCTAssertEqual(progressValues.last, 1)
        XCTAssertGreaterThan(progressValues.count, 1)
    }

    func testImporterHonorsCancellation() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 3)
        let importer = CSVZipAdapter()
        var cancellationChecks = 0

        XCTAssertThrowsError(try importer.importAll(
            from: zip,
            progress: nil,
            isCancelled: {
                cancellationChecks += 1
                return cancellationChecks > 1
            }
        )) { error in
            XCTAssertTrue(error is ImportError)
        }
    }

    func testImporterDoesNotReportInitialProgressWhenAlreadyCancelled() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 3)
        let importer = CSVZipAdapter()
        var progressValues: [Double] = []

        XCTAssertThrowsError(try importer.importAll(
            from: zip,
            progress: { progressValues.append($0) },
            isCancelled: { true }
        )) { error in
            XCTAssertTrue(error is ImportError)
        }
        XCTAssertTrue(progressValues.isEmpty)
    }
}

// MARK: - Entity: CSVZipAdapter (parsing/correctness tests)
final class CSVZipAdapterTests: XCTestCase {
    func testParsesCSVRowsIntoModels() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 5)
        let importer = CSVZipAdapter()
        XCTAssertTrue(importer.canImport(zip))
        XCTAssertNoThrow(try importer.importAll(from: zip, progress: nil, isCancelled: nil))
    }

    func testResolvesImageEntriesByName() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 2)
        let importer = CSVZipAdapter(
            imageStore: DefaultImageStore(baseDirectory: try ImportTestHelpers.temporaryDirectory(testName: "image_resolution"))
        )
        XCTAssertNoThrow(try importer.importAll(from: zip, progress: nil, isCancelled: nil))
    }
}

// MARK: - Entity: ImageStore (dedupe, thumbnails)
final class ImageStoreTests: XCTestCase {
    func testStoresImageWithContentAddressedHash() throws {
        let imgA = try ImportTestHelpers.makePNG()
        let store = DefaultImageStore(baseDirectory: try ImportTestHelpers.temporaryDirectory(testName: "dedupe"))

        let rec1 = try store.store(imgA, filenameHint: "a.png")
        let rec2 = try store.store(imgA, filenameHint: "duplicate.png")

        XCTAssertEqual(rec1.hash, rec2.hash)
        XCTAssertEqual(rec1.relativePath, rec2.relativePath)
    }

    func testThumbnailResizesStoredImageToRequestedBounds() throws {
        let img = try ImportTestHelpers.makePNG(width: 256, height: 128)
        let store = DefaultImageStore(baseDirectory: try ImportTestHelpers.temporaryDirectory(testName: "thumbnail"))
        let rec = try store.store(img, filenameHint: "photo.png")

        let thumb = try store.thumbnail(for: rec.hash, size: CGSize(width: 64, height: 64))

        XCTAssertFalse(thumb.isEmpty)
        let source = CGImageSourceCreateWithData(thumb as CFData, nil)
        let properties = CGImageSourceCopyPropertiesAtIndex(source!, 0, nil) as? [CFString: Any]
        XCTAssertEqual(properties?[kCGImagePropertyPixelWidth] as? Int, 64)
        XCTAssertEqual(properties?[kCGImagePropertyPixelHeight] as? Int, 32)
    }
}

// MARK: - Entity: ImportCoordinator
final class ImportCoordinatorTests: XCTestCase {
    func testCoordinatorDelegatesToImporter() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 3)
        let importer = CSVZipAdapter()
        let coordinator = DefaultImportCoordinator()

        XCTAssertNoThrow(try coordinator.startImport(using: importer, from: zip))
    }
}
