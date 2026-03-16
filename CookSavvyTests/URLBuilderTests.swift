//
//  URLBuilderTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class URLBuilderTests: XCTestCase {

    func testBaseURLWithPath() throws {
        let url = try URLBuilder(baseURL: "https://api.example.com", path: "recipes")
            .build()
        XCTAssertEqual(url.absoluteString, "https://api.example.com/recipes")
    }

    func testAppendingPath() throws {
        let url = try URLBuilder(baseURL: "https://api.example.com", path: "v1")
            .appendingPath("search")
            .build()
        XCTAssertEqual(url.absoluteString, "https://api.example.com/v1/search")
    }

    func testQueryParameterEncoding() throws {
        let url = try URLBuilder(baseURL: "https://api.example.com")
            .addingQueryParameter(key: "query", value: "chicken pasta")
            .build()
        // Space must be percent-encoded as %20, not left raw or encoded as +
        XCTAssertEqual(url.absoluteString, "https://api.example.com?query=chicken%20pasta")
    }

    func testMultipleParams() throws {
        let url = try URLBuilder(baseURL: "https://api.example.com")
            .withQueryParameters(["key": "abc123", "limit": "10"])
            .build()
        let query = url.query ?? ""
        XCTAssertTrue(query.contains("key=abc123"))
        XCTAssertTrue(query.contains("limit=10"))
    }

    func testEmptyParamsNoQuestionMark() throws {
        let url = try URLBuilder(baseURL: "https://api.example.com", path: "health")
            .build()
        XCTAssertFalse(url.absoluteString.contains("?"))
    }
}
