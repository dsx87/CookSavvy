//
//  NetworkService.swift
//  CookSavvy
//

import Foundation

final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    
    init(
        session: URLSession = .shared,
        configuration: NetworkConfiguration = .default,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.session = session
        self.configuration = configuration
        self.encoder = encoder
    }
    
    // MARK: - NetworkServiceProtocol
    
    func send(_ request: NetworkRequest) async throws -> NetworkResponse {
        let urlRequest = try buildURLRequest(from: request)
        
        var lastError: Error?
        
        for attempt in 0..<max(1, configuration.retryCount) {
            if attempt > 0 {
                try await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000))
            }
            
            do {
                let (data, response) = try await session.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.unknown(NSError(domain: "NetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]))
                }
                
                let networkResponse = NetworkResponse(
                    data: data,
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields
                )
                
                if !networkResponse.isSuccess {
                    throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
                }
                
                return networkResponse
                
            } catch let error as NetworkError {
                lastError = error
                if !isRetryable(error) {
                    throw error
                }
            } catch let urlError as URLError {
                lastError = mapURLError(urlError)
                if !isRetryable(urlError) {
                    throw lastError!
                }
            } catch {
                lastError = NetworkError.unknown(error)
                throw lastError!
            }
        }
        
        throw lastError ?? NetworkError.unknown(NSError(domain: "NetworkService", code: -1, userInfo: nil))
    }
    
    // MARK: - Private Methods
    
    private func buildURLRequest(from request: NetworkRequest) throws -> URLRequest {
        var url = request.url
        
        if let queryParameters = request.queryParameters, !queryParameters.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                throw NetworkError.invalidURL
            }
            
            var queryItems = components.queryItems ?? []
            queryItems.append(contentsOf: queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) })
            components.queryItems = queryItems
            
            guard let newURL = components.url else {
                throw NetworkError.invalidURL
            }
            url = newURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeoutInterval > 0 ? request.timeoutInterval : configuration.defaultTimeout
        
        for (key, value) in configuration.defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        if let headers = request.headers {
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = request.body {
            do {
                urlRequest.httpBody = try encodeBody(body)
            } catch {
                throw NetworkError.encodingFailed(error)
            }
        }
        
        return urlRequest
    }
    
    private func encodeBody(_ body: any Encodable) throws -> Data {
        return try encoder.encode(AnyEncodable(body))
    }
    
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        default:
            return .unknown(error)
        }
    }
    
    private func isRetryable(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .noConnection, .timeout:
                return true
            case .httpError(let statusCode, _):
                return statusCode >= 500
            default:
                return false
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - AnyEncodable

private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    init(_ wrapped: any Encodable) {
        _encode = wrapped.encode
    }
    
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
