//
//  NetworkConfiguration.swift
//  CookSavvy
//

import Foundation

/// Shared configuration applied to every request executed by ``NetworkService``.
///
/// Provides default timeout, headers, and retry behaviour. Individual ``NetworkRequest``
/// values can override the timeout and headers on a per-request basis.
struct NetworkConfiguration {
    /// Timeout in seconds applied when a ``NetworkRequest`` does not specify its own.
    let defaultTimeout: TimeInterval
    /// Headers merged into every outgoing request; per-request headers take precedence on collision.
    let defaultHeaders: [String: String]
    /// Maximum number of times to retry a transient failure before propagating the error.
    let retryCount: Int
    /// Seconds to wait between retry attempts.
    let retryDelay: TimeInterval

    /// Default configuration: 30 s timeout, JSON content/accept headers, 3 retries at 1 s intervals.
    static let `default` = NetworkConfiguration(
        defaultTimeout: 30,
        defaultHeaders: [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ],
        retryCount: 3,
        retryDelay: 1.0
    )
    
    /// Creates a custom ``NetworkConfiguration``.
    /// - Parameters:
    ///   - defaultTimeout: Request timeout in seconds. Defaults to `30`.
    ///   - defaultHeaders: Headers applied to every request. Defaults to empty.
    ///   - retryCount: Maximum retry attempts for transient failures. Defaults to `3`.
    ///   - retryDelay: Seconds between retry attempts. Defaults to `1.0`.
    init(
        defaultTimeout: TimeInterval = 30,
        defaultHeaders: [String: String] = [:],
        retryCount: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) {
        self.defaultTimeout = defaultTimeout
        self.defaultHeaders = defaultHeaders
        self.retryCount = retryCount
        self.retryDelay = retryDelay
    }
}
