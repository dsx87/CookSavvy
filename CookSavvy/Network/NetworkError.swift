//
//  NetworkError.swift
//  CookSavvy
//

import Foundation

/// Errors thrown by ``NetworkService`` during request execution or response handling.
enum NetworkError: Error, LocalizedError {
    /// The URL could not be constructed or was malformed.
    case invalidURL
    /// The device has no active network connection.
    case noConnection
    /// The request exceeded its allowed time limit.
    case timeout
    /// The server returned a non-2xx HTTP status code.
    case httpError(statusCode: Int, data: Data?)
    /// The response body could not be decoded into the expected type.
    case decodingFailed(Error)
    /// The request body could not be serialised to JSON.
    case encodingFailed(Error)
    /// An unexpected error not covered by the other cases.
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode request body: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
