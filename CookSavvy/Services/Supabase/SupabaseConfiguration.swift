//
//  SupabaseConfiguration.swift
//  CookSavvy
//

import Foundation
import os

struct SupabaseConfiguration {
    let projectURLKey = "SUPABASE_URL"
    let anonKeyKey = "SUPABASE_ANON_KEY"

    /// Supabase anon keys are client-safe publishable keys, not secrets.
    private(set) var projectURL: URL?
    private(set) var anonKey: String?

    var isConfigured: Bool {
        projectURL != nil && !(anonKey?.isEmpty ?? true)
    }

    init(bundle: Bundle = .main) {
        let logger = Logger(
            subsystem: bundle.bundleIdentifier ?? "CookSavvy",
            category: "SupabaseConfiguration"
        )
        
        self.projectURL = readProjectURL(from: bundle, logger: logger)
        self.anonKey = getValue(for: anonKeyKey, bundle: bundle, logger: logger)
    }

    init(projectURL: URL?, anonKey: String?) {
        self.projectURL = projectURL
        self.anonKey = anonKey
    }

    init(projectURLString: String?, anonKey: String?) {
        self.projectURL = Self.parseProjectURL(projectURLString)
        self.anonKey = anonKey
    }

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
