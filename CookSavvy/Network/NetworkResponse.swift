//
//  NetworkResponse.swift
//  CookSavvy
//

import Foundation

/// Value type wrapping a raw HTTP response received by ``NetworkService``.
struct NetworkResponse {
    
    // MARK: - Properties
    
    /// Raw body data returned by the server.
    let data: Data
    /// HTTP status code (e.g. 200, 404).
    let statusCode: Int
    /// Response headers returned by the server.
    let headers: [AnyHashable: Any]
    
    // MARK: - Decoding
    
    /// Decodes the response body into the given `Decodable` type.
    /// - Parameters:
    ///   - type: The expected response model type.
    ///   - decoder: The `JSONDecoder` to use. Defaults to a plain instance.
    /// - Returns: A decoded instance of `T`.
    /// - Throws: ``NetworkError/decodingFailed(_:)`` if the body cannot be decoded.
    func decode<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    // MARK: - Convenience
    
    /// `true` if ``statusCode`` falls in the 200–299 success range.
    var isSuccess: Bool {
        return (200..<300).contains(statusCode)
    }
    
    /// The response body decoded as a UTF-8 string, or `nil` if the data is not valid UTF-8.
    var stringValue: String? {
        return String(data: data, encoding: .utf8)
    }
}
