//
//  CVSDecoderTests.swift
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
    
    var dec: CSVDecoder!
    
    override func setUpWithError() throws {
        dec = CSVDecoder()
    }

    override func tearDownWithError() throws {
        dec = nil
    }

    func testDecoding() throws {
        let dec = CSVDecoder()
        let data = try XCTUnwrap(csvString.data(using: .utf8))
        let res = try dec.decode([TestStruct].self, from: data)
        XCTAssertFalse(res.isEmpty)
    }

}
