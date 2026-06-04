//
//  APIKeysReader.swift
//  CookSavvy
//

import Foundation
import os

/// Reads client-safe string values from the gitignored `Support/APIKeys.plist`.
///
/// This is the shared primitive behind the configuration structs that resolve third-party
/// identifiers (TelemetryDeck app ID, Sentry DSN). It mirrors the missing/unreadable/empty
/// handling that `SupabaseConfiguration` performs for its own keys: a missing plist, an
/// unreadable plist, or an absent/empty value all resolve to `nil` so the dependent integration
/// stays inert rather than crashing or shipping a half-configured client.
///
/// Only client-safe, publishable identifiers belong in `APIKeys.plist` — never backend secrets.
enum APIKeysReader {
    /// Returns the trimmed string value for `key` in `APIKeys.plist`, or `nil` when the plist is
    /// missing/unreadable or the value is absent or empty.
    /// - Parameters:
    ///   - key: The `APIKeys.plist` top-level key to look up.
    ///   - bundle: The bundle to search for `APIKeys.plist`. Defaults to `.main`.
    static func string(_ key: String, bundle: Bundle = .main) -> String? {
        let logger = Logger(
            subsystem: bundle.bundleIdentifier ?? "CookSavvy",
            category: "APIKeysReader"
        )
        guard let path = bundle.path(forResource: "APIKeys", ofType: "plist") else {
            logger.notice("APIKeys.plist not found in app bundle. '\(key, privacy: .public)' is inactive.")
            return nil
        }
        guard let dict = NSDictionary(contentsOfFile: path) else {
            logger.warning("APIKeys.plist could not be read. '\(key, privacy: .public)' is inactive.")
            return nil
        }
        guard let value = dict[key] as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}
