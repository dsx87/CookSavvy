//
//  NetworkConfiguration.swift
//  CookSavvy
//

import Foundation

struct NetworkConfiguration {
    let defaultTimeout: TimeInterval
    let defaultHeaders: [String: String]
    let retryCount: Int
    let retryDelay: TimeInterval
    
    static let `default` = NetworkConfiguration(
        defaultTimeout: 30,
        defaultHeaders: [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ],
        retryCount: 3,
        retryDelay: 1.0
    )
    
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
