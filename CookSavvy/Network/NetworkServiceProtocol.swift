//
//  NetworkServiceProtocol.swift
//  CookSavvy
//

import Foundation

/// Protocol defining the interface for executing HTTP network requests.
protocol NetworkServiceProtocol {
    /// Sends a network request and returns the response.
    /// - Parameter request: The ``NetworkRequest`` to execute.
    /// - Returns: A ``NetworkResponse`` containing the raw data, status code, and headers.
    /// - Throws: ``NetworkError`` if the request fails or the server returns a non-2xx status.
    func send(_ request: NetworkRequest) async throws -> NetworkResponse
}
