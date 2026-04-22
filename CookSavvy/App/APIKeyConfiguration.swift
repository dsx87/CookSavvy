//
//  APIKeyConfiguration.swift
//  CookSavvy
//

import Foundation
import os

/// Reads API keys from the `APIKeys.plist` bundle resource.
///
/// Keys are stored in a gitignored plist to keep secrets out of source control.
/// Missing or empty values are treated as absent, and callers receive `nil` rather than
/// an empty string. The legacy OpenAI and Gemini keys are still readable here but are
/// no longer wired into the active app at runtime; Supabase keys are consumed directly
/// by `SupabaseConfiguration`.
enum APIKeyConfiguration {
    private static let plistName = "APIKeys"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CookSavvy",
        category: "APIKeyConfiguration"
    )

    /// The legacy OpenAI API key, if present and non-empty in `APIKeys.plist`.
    static var openAIKey: String? {
        getValue(for: "OPENAI_API_KEY")
    }

    /// The legacy Gemini API key, if present and non-empty in `APIKeys.plist`.
    static var geminiKey: String? {
        getValue(for: "GEMINI_API_KEY")
    }

    /// Looks up `key` in `APIKeys.plist`, returning `nil` if the plist is missing,
    /// unreadable, or does not contain a non-empty string for `key`.
    ///
    /// - Parameter key: The plist dictionary key to look up.
    /// - Returns: The non-empty string value, or `nil`.
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
