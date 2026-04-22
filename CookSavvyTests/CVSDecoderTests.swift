//
//  CSVDecoderTests.swift
//  CookSavvyTests
//
//  Created by Igor Pivnyk on 01/09/2025.
//

import XCTest

@testable import CookSavvy

final class CSVDecoderTests: XCTestCase {
    
    let csvString: String =
    #"""
    "id","name","quote","age","balance","unicode","empty"
    "1","Alice","Hello, world!","25","1000.50","こんにちは",""
    "2","Bob, Jr.","""This is a quote inside quotes""","","-200.75","😀",""
    "3","""Charlie""","Line1
    Line2
    Line3","35","0","naïve",""
    "4","D'Artagnan","Comma, inside, text","40","1,234.56","façade"," "
    "5","Eve","Escaped ""quote"" and backslash \","unknown","null","россия",""
    """#
    
    struct TestStruct: Codable {
        let id: String
        let name: String
        let quote: String
        let age: String
        let balance: String
        let unicode: String
        let empty: String
    }
    
    var decoder: CSVDecoder!
    
    override func setUpWithError() throws {
        decoder = CSVDecoder()
    }

    override func tearDownWithError() throws {
        decoder = nil
    }

    func testDecoding() throws {
        let decoder = CSVDecoder()
        let data = try XCTUnwrap(csvString.data(using: .utf8))
        let decodedRows = try decoder.decode([TestStruct].self, from: data)
        XCTAssertFalse(decodedRows.isEmpty)
    }

    func testMalformedRowsAreSkippedDuringArrayDecoding() throws {
        struct Row: Decodable {
            let id: Int
            let name: String
        }

        let csv = """
        id,name
        1,Salt
        bad,Pepper
        2,Oil
        """

        let rows = try decoder.decode([Row].self, from: csv)
        XCTAssertEqual(rows.map(\.id), [1, 2])
    }

    func testGenericFoundationTypesDecodeWithoutForceCasts() throws {
        struct Row: Decodable {
            let date: Date
            let data: Data
            let url: URL
        }

        let payload = Data("hello".utf8).base64EncodedString()
        let csv = """
        date,data,url
        42,\(payload),https://example.com
        """

        decoder.dateDecodingStrategy = .secondsSince1970
        let row = try decoder.decode(Row.self, from: csv)

        XCTAssertEqual(row.date.timeIntervalSince1970, 42)
        XCTAssertEqual(row.data, Data("hello".utf8))
        XCTAssertEqual(row.url.absoluteString, "https://example.com")
    }

    func testInvalidGenericFoundationValuesThrowWhenDecodingSingleRow() throws {
        struct Row: Decodable {
            let url: URL
        }

        let csv = """
        url
        http://[::1
        """

        XCTAssertThrowsError(try decoder.decode(Row.self, from: csv))
    }

}
