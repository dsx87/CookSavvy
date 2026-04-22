//
//  NetworkService.swift
//  CookSavvy
//

import Foundation

/// Concrete HTTP client that executes ``NetworkRequest`` values using `URLSession`.
///
/// Applies global defaults from ``NetworkConfiguration`` (timeout, headers) to every request
/// and automatically retries transient failures — no-connection, timeout, and HTTP 5xx responses —
/// up to `configuration.retryCount` times with a fixed `configuration.retryDelay` between attempts.
final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    
    /// Creates a `NetworkService` with the given session, configuration, and encoder.
    /// - Parameters:
    ///   - session: The `URLSession` used to make requests. Defaults to `.shared`.
    ///   - configuration: Global networking defaults. Defaults to ``NetworkConfiguration/default``.
    ///   - encoder: The `JSONEncoder` used to serialise request bodies.
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
    
    /// Sends the request, retrying on transient failures up to `configuration.retryCount` times.
    ///
    /// The retry loop sleeps `configuration.retryDelay` seconds between attempts. Only
    /// ``NetworkError/noConnection``, ``NetworkError/timeout``, and HTTP 5xx responses trigger
    /// a retry; all other errors are rethrown immediately without further attempts.
    ///
    /// - Parameter request: The ``NetworkRequest`` to execute.
    /// - Returns: A ``NetworkResponse`` containing the server's data, status code, and headers.
    /// - Throws: ``NetworkError`` on unrecoverable failures or after all retries are exhausted.
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
    
    /// Constructs a `URLRequest` from a ``NetworkRequest``, merging global configuration defaults
    /// with per-request overrides for headers and timeout, and appending any query parameters.
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
    
    /// Type-erases an `Encodable` value and encodes it to `Data` using the shared `JSONEncoder`.
    private func encodeBody(_ body: any Encodable) throws -> Data {
        return try encoder.encode(AnyEncodable(body))
    }
    
    /// Maps a `URLError` to the closest semantic ``NetworkError``.
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
    
    /// Returns `true` if the error represents a transient condition worth retrying.
    ///
    /// Retryable: ``NetworkError/noConnection``, ``NetworkError/timeout``, HTTP 5xx status codes,
    /// and the equivalent `URLError` connection/timeout codes.
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

/// Type-erasing wrapper that lets `JSONEncoder` encode any `Encodable` value without
/// requiring a concrete generic type at the call site.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    
    /// Captures the wrapped value's `Encodable` implementation for later forwarding.
    init(_ wrapped: any Encodable) {
        _encode = wrapped.encode
    }
    
    /// Forwards encoding to the stored closure from the wrapped value.
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
