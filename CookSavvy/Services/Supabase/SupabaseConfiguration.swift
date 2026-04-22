//
//  SupabaseConfiguration.swift
//  CookSavvy
//

import Foundation
import os

/// Reads the Supabase project URL and anon key from `Support/APIKeys.plist`.
///
/// When either value is absent or invalid, all properties remain `nil` and `isConfigured`
/// returns `false`, causing the app to fall back to offline-only mode. The anon key is a
/// client-safe publishable credential — it is not a secret and is safe to ship in the app binary.
struct SupabaseConfiguration {
    /// The `APIKeys.plist` key used to look up the Supabase project URL.
    let projectURLKey = "SUPABASE_URL"
    /// The `APIKeys.plist` key used to look up the Supabase anon key.
    let anonKeyKey = "SUPABASE_ANON_KEY"

    /// Supabase anon keys are client-safe publishable keys, not secrets.
    private(set) var projectURL: URL?
    /// The Supabase anon (publishable) key read from `APIKeys.plist`.
    private(set) var anonKey: String?

    /// `true` when both `projectURL` and a non-empty `anonKey` are available.
    var isConfigured: Bool {
        projectURL != nil && !(anonKey?.isEmpty ?? true)
    }

    /// Reads Supabase credentials from `APIKeys.plist` in the given bundle.
    /// - Parameter bundle: The bundle to search for `APIKeys.plist`. Defaults to `.main`.
    init(bundle: Bundle = .main) {
        let logger = Logger(
            subsystem: bundle.bundleIdentifier ?? "CookSavvy",
            category: "SupabaseConfiguration"
        )
        
        self.projectURL = readProjectURL(from: bundle, logger: logger)
        self.anonKey = getValue(for: anonKeyKey, bundle: bundle, logger: logger)
    }

    /// Initializes directly with already-resolved values. Intended for testing.
    /// - Parameters:
    ///   - projectURL: The Supabase project URL, or `nil` to represent an unconfigured state.
    ///   - anonKey: The Supabase anon key, or `nil` to represent an unconfigured state.
    init(projectURL: URL?, anonKey: String?) {
        self.projectURL = projectURL
        self.anonKey = anonKey
    }

    /// Initializes from a raw URL string, parsing it into a `URL`. Intended for testing.
    /// - Parameters:
    ///   - projectURLString: Raw string form of the project URL.
    ///   - anonKey: The Supabase anon key.
    init(projectURLString: String?, anonKey: String?) {
        self.projectURL = Self.parseProjectURL(projectURLString)
        self.anonKey = anonKey
    }

    /// Reads the raw URL string from the plist and validates it via `parseProjectURL`.
    private func readProjectURL(from bundle: Bundle, logger: Logger) -> URL? {
        guard let value = getValue(for: projectURLKey, bundle: bundle, logger: logger) else {
            return nil
        }

        guard let url = Self.parseProjectURL(value) else {
            logger.warning("SUPABASE_URL exists but is not a valid URL.")
            return nil
        }

        return url
    }

    /// Validates that the string is an absolute HTTP/HTTPS URL with a non-nil host.
    /// Returns `nil` for relative URLs, non-HTTP schemes, or malformed strings.
    private static func parseProjectURL(_ value: String?) -> URL? {
        guard
            let value,
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host != nil
        else {
            return nil
        }

        return components.url
    }

    /// Reads a string value for `key` from `APIKeys.plist` in the given bundle.
    /// Returns `nil` if the plist is missing, unreadable, or the key is absent/empty.
    private func getValue(for key: String, bundle: Bundle, logger: Logger) -> String? {
        guard let path = bundle.path(forResource: "APIKeys", ofType: "plist") else {
            logger.notice("APIKeys.plist not found in app bundle. Supabase placeholders are inactive.")
            return nil
        }
        guard let dict = NSDictionary(contentsOfFile: path) else {
            logger.warning("APIKeys.plist could not be read. Supabase placeholders are inactive.")
            return nil
        }
        guard let value = dict[key] as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}
