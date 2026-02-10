//
//  NetworkServiceProtocol.swift
//  CookSavvy
//

import Foundation

protocol NetworkServiceProtocol {
    func send(_ request: NetworkRequest) async throws -> NetworkResponse
}
