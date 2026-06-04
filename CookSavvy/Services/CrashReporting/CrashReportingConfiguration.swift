//
//  CrashReportingConfiguration.swift
//  CookSavvy
//

import Foundation

/// Resolves the Sentry DSN from `Support/APIKeys.plist`.
///
/// When the DSN is absent, `isConfigured` is `false` and crash reporting stays a no-op. A Sentry
/// DSN is a client-safe ingestion endpoint, not a secret — consistent with how the Supabase anon
/// key is shipped.
struct CrashReportingConfiguration {
    /// The `APIKeys.plist` key used to look up the Sentry DSN.
    static let dsnKey = "SENTRY_DSN"

    /// The Sentry DSN, or `nil` when unconfigured.
    private(set) var dsn: String?

    /// `true` when a non-empty `dsn` is available.
    var isConfigured: Bool { !(dsn?.isEmpty ?? true) }

    /// Reads the Sentry DSN from `APIKeys.plist` in the given bundle.
    /// - Parameter bundle: The bundle to search for `APIKeys.plist`. Defaults to `.main`.
    init(bundle: Bundle = .main) {
        self.dsn = APIKeysReader.string(Self.dsnKey, bundle: bundle)
    }

    /// Initializes directly with an already-resolved value. Intended for testing.
    init(dsn: String?) {
        self.dsn = dsn
    }
}
