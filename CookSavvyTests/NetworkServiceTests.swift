//
//  NetworkServiceTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - NetworkServiceTests

final class NetworkServiceTests: XCTestCase {

    var service: NetworkService!
    var session: URLSession!
    let testURL = URL(string: "https://api.example.com/test")!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = NetworkService(session: session)
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        service = nil
        session = nil
        super.tearDown()
    }

    func testSuccessfulResponse() async throws {
        let expectedData = #"{"status":"ok"}"#.data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: self.testURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, expectedData)
        }

        let request = NetworkRequest.get(url: testURL)
        let response = try await service.send(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.data, expectedData)
    }

    func testHTTPErrorThrows() async {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: self.testURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let request = NetworkRequest.get(url: testURL)
        do {
            _ = try await service.send(request)
            XCTFail("Expected NetworkError.httpError to be thrown")
        } catch let error as NetworkError {
            if case .httpError(let code, _) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTimeoutThrows() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        // Use retryCount=1 and retryDelay=0 so the test completes without waiting for retry delays
        let fastConfig = NetworkConfiguration(defaultTimeout: 30, defaultHeaders: [:], retryCount: 1, retryDelay: 0)
        let fastService = NetworkService(session: session, configuration: fastConfig)

        let request = NetworkRequest.get(url: testURL)
        do {
            _ = try await fastService.send(request)
            XCTFail("Expected NetworkError.timeout to be thrown")
        } catch let error as NetworkError {
            if case .timeout = error {
                // Expected
            } else {
                XCTFail("Expected timeout error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
