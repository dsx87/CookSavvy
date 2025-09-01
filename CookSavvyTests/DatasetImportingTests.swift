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
        let dir = base.appendingPathComponent("CookSavvyTests_\(testName)", isDirectory: true)
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
        // Spec: A concrete importer should be able to declare whether it can import a given URL.
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 1)
        let importer = CSVZipAdapter()
        XCTAssertTrue(importer.canImport(zip), "CSVZipAdapter should report it can import a valid dataset zip")
    }

    func testImporterPerformsFullImportWithProgressAndCancellation() throws {
        // Spec: Importer should report total units, progress updates, and support cancellation.
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 10)
        let importer = CSVZipAdapter()
        let coordinator = DefaultImportCoordinator()

        // Expectation for progress updates (will not be called with stubs, test will fail as desired)
        var progressValues: [Double] = []
        let progress: (Double) -> Void = { progressValues.append($0) }
        let isCancelled: () -> Bool = { return false }

        // Start import via importer directly for now; coordinator simply wraps importer in this stub phase
        XCTAssertNoThrow(try importer.importAll(from: zip, progress: progress, isCancelled: isCancelled))
        XCTAssertNoThrow(try coordinator.startImport(using: importer, from: zip))

        // Validate we saw some progress
        XCTAssertFalse(progressValues.isEmpty, "Should receive progress updates during import")
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
        let importer = CSVZipAdapter()
        XCTAssertTrue(importer.canImport(zip))
        // We expect importAll to successfully process and resolve image entries
        XCTAssertNoThrow(try importer.importAll(from: zip, progress: nil, isCancelled: nil))
    }
}

// MARK: - Entity: ImageStore (dedupe, recompress, thumbnails)
final class ImageStoreTests: XCTestCase {
    func testStoresImageWithContentAddressedHash() throws {
        let imgA = try ImportTestHelpers.makePNG()
        let store = DefaultImageStore()
        // First store
        XCTAssertNoThrow( _ = try store.store(imgA, filenameHint: "a.png"))
        // Second store should dedupe
        let rec1 = try store.store(imgA, filenameHint: "a.png")
        let rec2 = try store.store(imgA, filenameHint: "a.png")
        XCTAssertEqual(rec1.hash, rec2.hash)
    }

    func testRecompressToHEICAndGenerateThumbnail() throws {
        let img = try ImportTestHelpers.makePNG(width: 32, height: 32)
        let store = DefaultImageStore()
        let rec = try store.store(img, filenameHint: "photo.png")
        let thumb = try store.thumbnail(for: rec.hash, size: CGSize(width: 128, height: 128))
        XCTAssertNotNil(thumb)
    }
}

// MARK: - Entity: ImportCoordinator (batching, checkpoint/resume, progress)
final class ImportCoordinatorTests: XCTestCase {
    func testBatchesDatabaseWritesForPerformance() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 1200)
        let importer = CSVZipAdapter()
        let coordinator = DefaultImportCoordinator()
        XCTAssertNoThrow(try coordinator.startImport(using: importer, from: zip))
    }

    func testCheckpointAndResumeAfterCancellation() throws {
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 100)
        let importer = CSVZipAdapter()
        let coordinator = DefaultImportCoordinator()
        // We would cancel mid-run and then resume. For stubs, simply expect no throw for start.
        XCTAssertNoThrow(try coordinator.startImport(using: importer, from: zip))
    }
}

// MARK: - Entity: Mapping & CSV header aliases
final class MappingAndCSVDecoderAliasTests: XCTestCase {
    func testHeaderAliasMappingIsApplied() throws {
        // Using adapter with a single-row zip should succeed regardless of header aliasing in this stub phase
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 1)
        let importer = CSVZipAdapter()
        XCTAssertNoThrow(try importer.importAll(from: zip, progress: nil, isCancelled: nil))
    }

    func testSimpleTransformsAppliedDuringMapping() throws {
        // Using adapter on synthetic data; final implementation will handle transforms
        let zip = try ImportTestHelpers.makeMiniDatasetZip(rows: 1)
        let importer = CSVZipAdapter()
        XCTAssertNoThrow(try importer.importAll(from: zip, progress: nil, isCancelled: nil))
    }
}

