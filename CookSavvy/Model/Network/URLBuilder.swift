//
//  URLBuilder.swift
//  CookSavvy
//

import Foundation

struct URLBuilder {
    
    // MARK: - Properties
    
    var baseURL: String
    var path: String
    var queryParameters: [String: String]
    
    // MARK: - Initialization
    
    init(baseURL: String, path: String = "", queryParameters: [String: String] = [:]) {
        self.baseURL = baseURL
        self.path = path
        self.queryParameters = queryParameters
    }
    
    // MARK: - Builder Methods
    
    func withPath(_ path: String) -> URLBuilder {
        var builder = self
        builder.path = path
        return builder
    }
    
    func appendingPath(_ pathComponent: String) -> URLBuilder {
        var builder = self
        if builder.path.isEmpty {
            builder.path = pathComponent
        } else {
            builder.path = builder.path + "/" + pathComponent
        }
        return builder
    }
    
    func withQueryParameters(_ parameters: [String: String]) -> URLBuilder {
        var builder = self
        builder.queryParameters = parameters
        return builder
    }
    
    func addingQueryParameter(key: String, value: String) -> URLBuilder {
        var builder = self
        builder.queryParameters[key] = value
        return builder
    }
    
    // MARK: - Build
    
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
