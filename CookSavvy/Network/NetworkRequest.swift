//
//  NetworkRequest.swift
//  CookSavvy
//

import Foundation

struct NetworkRequest {
    
    // MARK: - Properties
    
    let method: HTTPMethod
    let url: URL
    let headers: [String: String]?
    let queryParameters: [String: String]?
    let body: (any Encodable)?
    let timeoutInterval: TimeInterval
    
    // MARK: - Initialization
    
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
