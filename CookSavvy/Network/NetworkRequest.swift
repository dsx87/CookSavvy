//
//  NetworkRequest.swift
//  CookSavvy
//

import Foundation

/// Value type encapsulating all parameters needed to describe a single outgoing HTTP request.
struct NetworkRequest {
    
    // MARK: - Properties
    
    /// HTTP method for the request.
    let method: HTTPMethod
    /// Target URL. Query parameters in ``queryParameters`` are appended by ``NetworkService`` before sending.
    let url: URL
    /// Per-request headers that override or extend ``NetworkConfiguration/defaultHeaders``.
    let headers: [String: String]?
    /// Key-value pairs appended to the URL as query string parameters.
    let queryParameters: [String: String]?
    /// Optional request body, encoded as JSON by ``NetworkService``.
    let body: (any Encodable)?
    /// Per-request timeout in seconds; `0` or negative defers to ``NetworkConfiguration/defaultTimeout``.
    let timeoutInterval: TimeInterval
    
    // MARK: - Initialization
    
    /// Creates a fully configured ``NetworkRequest``.
    init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String]? = nil,
        queryParameters: [String: String]? = nil,
        body: (any Encodable)? = nil,
        timeoutInterval: TimeInterval = 30
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.queryParameters = queryParameters
        self.body = body
        self.timeoutInterval = timeoutInterval
    }
    
    // MARK: - Convenience Initializers
    
    /// Returns a GET request targeting the given URL.
    static func get(
        url: URL,
        headers: [String: String]? = nil,
        queryParameters: [String: String]? = nil,
        timeoutInterval: TimeInterval = 30
    ) -> NetworkRequest {
        NetworkRequest(
            method: .get,
            url: url,
            headers: headers,
            queryParameters: queryParameters,
            timeoutInterval: timeoutInterval
        )
    }
    
    /// Returns a POST request with the given JSON-encodable body.
    static func post<T: Encodable>(
        url: URL,
        body: T,
        headers: [String: String]? = nil,
        timeoutInterval: TimeInterval = 30
    ) -> NetworkRequest {
        NetworkRequest(
            method: .post,
            url: url,
            headers: headers,
            body: body,
            timeoutInterval: timeoutInterval
        )
    }
    
    /// Returns a PUT request with the given JSON-encodable body.
    static func put<T: Encodable>(
        url: URL,
        body: T,
        headers: [String: String]? = nil,
        timeoutInterval: TimeInterval = 30
    ) -> NetworkRequest {
        NetworkRequest(
            method: .put,
            url: url,
            headers: headers,
            body: body,
            timeoutInterval: timeoutInterval
        )
    }
    
    /// Returns a DELETE request targeting the given URL.
    static func delete(
        url: URL,
        headers: [String: String]? = nil,
        timeoutInterval: TimeInterval = 30
    ) -> NetworkRequest {
        NetworkRequest(
            method: .delete,
            url: url,
            headers: headers,
            timeoutInterval: timeoutInterval
        )
    }
}
