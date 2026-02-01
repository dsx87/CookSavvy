//
//  NetworkResponse.swift
//  CookSavvy
//

import Foundation

struct NetworkResponse {
    
    // MARK: - Properties
    
    let data: Data
    let statusCode: Int
    let headers: [AnyHashable: Any]
    
    // MARK: - Decoding
    
    func decode<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    // MARK: - Convenience
    
    var isSuccess: Bool {
        return (200..<300).contains(statusCode)
    }
    
    var stringValue: String? {
        return String(data: data, encoding: .utf8)
    }
}
