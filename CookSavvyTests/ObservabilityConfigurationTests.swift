//
//  ObservabilityConfigurationTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

/// Covers the analytics/crash configuration readers that decide whether the remote integrations
/// (TelemetryDeck, Sentry) are active. Both fall back to inert behavior when their key is absent.
final class ObservabilityConfigurationTests: XCTestCase {

    // MARK: - APIKeysReader

    @MainActor
    func testAPIKeysReaderReturnsNilWhenPlistAbsentFromBundle() async {
        // The unit-test bundle does not contain APIKeys.plist, so any lookup resolves to nil.
        let testBundle = Bundle(for: Self.self)
        XCTAssertNil(APIKeysReader.string("TELEMETRYDECK_APP_ID", bundle: testBundle))
        XCTAssertNil(APIKeysReader.string("SENTRY_DSN", bundle: testBundle))
    }

    // MARK: - TelemetryDeckConfiguration

    @MainActor
    func testTelemetryDeckConfiguredWithNonEmptyAppID() async {
        let config = TelemetryDeckConfiguration(appID: "ABC-123")
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.appID, "ABC-123")
    }

    @MainActor
    func testTelemetryDeckNotConfiguredWhenAppIDNil() async {
        XCTAssertFalse(TelemetryDeckConfiguration(appID: nil).isConfigured)
    }

    @MainActor
    func testTelemetryDeckNotConfiguredWhenAppIDEmpty() async {
        XCTAssertFalse(TelemetryDeckConfiguration(appID: "").isConfigured)
    }

    @MainActor
    func testTelemetryDeckReadsFromBundleWithoutPlist() async {
        // No APIKeys.plist in the test bundle → unconfigured, app falls back to os.Logger analytics.
        let config = TelemetryDeckConfiguration(bundle: Bundle(for: Self.self))
        XCTAssertFalse(config.isConfigured)
    }

    // MARK: - CrashReportingConfiguration

    @MainActor
    func testCrashReportingConfiguredWithNonEmptyDSN() async {
        let config = CrashReportingConfiguration(dsn: "https://key@example.ingest.sentry.io/1")
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.dsn, "https://key@example.ingest.sentry.io/1")
    }

    @MainActor
    func testCrashReportingNotConfiguredWhenDSNNil() async {
        XCTAssertFalse(CrashReportingConfiguration(dsn: nil).isConfigured)
    }

    @MainActor
    func testCrashReportingNotConfiguredWhenDSNEmpty() async {
        XCTAssertFalse(CrashReportingConfiguration(dsn: "").isConfigured)
    }
}
