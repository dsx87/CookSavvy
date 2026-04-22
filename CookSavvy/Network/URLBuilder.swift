//
//  URLBuilder.swift
//  CookSavvy
//

import Foundation

/// Fluent builder for constructing `URL` values from a base URL, an optional path, and query parameters.
///
/// All mutating methods return a new `URLBuilder` (value-type copy), making it safe to branch
/// from a shared base:
///
/// ```swift
/// let base = URLBuilder(baseURL: "https://api.example.com")
/// let usersURL  = try base.withPath("users").build()
/// let searchURL = try base.withPath("search").addingQueryParameter(key: "q", value: "pasta").build()
/// ```
struct URLBuilder {
    
    // MARK: - Properties
    
    /// The scheme + host (and optional port) used as the root of every built URL.
    var baseURL: String
    /// Path component appended after the base URL.
    var path: String
    /// Query parameters serialised as the URL's query string on ``build()``.
    var queryParameters: [String: String]
    
    // MARK: - Initialization
    
    /// Creates a ``URLBuilder`` with the given base URL, optional path, and optional query parameters.
    init(baseURL: String, path: String = "", queryParameters: [String: String] = [:]) {
        self.baseURL = baseURL
        self.path = path
        self.queryParameters = queryParameters
    }
    
    // MARK: - Builder Methods
    
    /// Returns a copy of the builder with the path replaced by the given value.
    func withPath(_ path: String) -> URLBuilder {
        var builder = self
        builder.path = path
        return builder
    }
    
    /// Returns a copy with `pathComponent` appended to the existing path, inserting a `/` separator as needed.
    func appendingPath(_ pathComponent: String) -> URLBuilder {
        var builder = self
        if builder.path.isEmpty {
            builder.path = pathComponent
        } else {
            builder.path = builder.path + "/" + pathComponent
        }
        return builder
    }
    
    /// Returns a copy with the query parameters replaced by the given dictionary.
    func withQueryParameters(_ parameters: [String: String]) -> URLBuilder {
        var builder = self
        builder.queryParameters = parameters
        return builder
    }
    
    /// Returns a copy with one additional query parameter added (or updated if the key already exists).
    func addingQueryParameter(key: String, value: String) -> URLBuilder {
        var builder = self
        builder.queryParameters[key] = value
        return builder
    }
    
    // MARK: - Build
    
    /// Combines ``baseURL``, ``path``, and ``queryParameters`` into a `URL`.
    /// - Returns: The fully constructed `URL`.
    /// - Throws: ``NetworkError/invalidURL`` if the resulting string cannot be parsed as a valid URL.
    func build() throws -> URL {
        var urlString = baseURL
        
        if !path.isEmpty {
            if !urlString.hasSuffix("/") && !path.hasPrefix("/") {
                urlString += "/"
            }
            urlString += path
        }
        
        guard var components = URLComponents(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        if !queryParameters.isEmpty {
            components.queryItems = queryParameters.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        return url
    }
}
