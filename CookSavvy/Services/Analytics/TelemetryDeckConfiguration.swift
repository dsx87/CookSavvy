//
//  TelemetryDeckConfiguration.swift
//  CookSavvy
//

import Foundation

/// Resolves the TelemetryDeck application identifier from `Support/APIKeys.plist`.
///
/// When the identifier is absent, `isConfigured` is `false` and the app falls back to the local
/// `os.Logger` analytics implementation (`AnalyticsService`). A TelemetryDeck app ID is a
/// client-safe identifier, not a secret — consistent with how the Supabase anon key is shipped.
struct TelemetryDeckConfiguration {
    /// The `APIKeys.plist` key used to look up the TelemetryDeck application identifier.
    static let appIDKey = "TELEMETRYDECK_APP_ID"

    /// The TelemetryDeck application identifier, or `nil` when unconfigured.
    private(set) var appID: String?

    /// `true` when a non-empty `appID` is available.
    var isConfigured: Bool { !(appID?.isEmpty ?? true) }

    /// Reads the TelemetryDeck app ID from `APIKeys.plist` in the given bundle.
    /// - Parameter bundle: The bundle to search for `APIKeys.plist`. Defaults to `.main`.
    init(bundle: Bundle = .main) {
        self.appID = APIKeysReader.string(Self.appIDKey, bundle: bundle)
    }

    /// Initializes directly with an already-resolved value. Intended for testing.
    init(appID: String?) {
        self.appID = appID
    }
}
