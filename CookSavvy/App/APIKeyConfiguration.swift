//
//  APIKeyConfiguration.swift
//  CookSavvy
//

import Foundation
import os

enum APIKeyConfiguration {
    private static let plistName = "APIKeys"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "APIKeyConfiguration"
    )
    
    static var openAIKey: String? {
        getValue(for: "OPENAI_API_KEY")
    }
    
    static var geminiKey: String? {
        getValue(for: "GEMINI_API_KEY")
    }
    
    private static func getValue(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: plistName, ofType: "plist") else {
            logger.warning("APIKeys.plist not found in app bundle. AI provider keys unavailable.")
            return nil
        }
        guard let dict = NSDictionary(contentsOfFile: path) else {
            logger.warning("APIKeys.plist could not be read. AI provider keys unavailable.")
            return nil
        }
        guard let value = dict[key] as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}
