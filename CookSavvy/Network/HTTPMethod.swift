//
//  HTTPMethod.swift
//  CookSavvy
//

import Foundation

/// Supported HTTP methods used when constructing ``NetworkRequest`` values.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
