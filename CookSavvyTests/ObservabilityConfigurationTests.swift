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

    func testAPIKeysReaderReturnsNilWhenPlistAbsentFromBundle() {
        // The unit-test bundle does not contain APIKeys.plist, so any lookup resolves to nil.
        let testBundle = Bundle(for: Self.self)
        XCTAssertNil(APIKeysReader.string("TELEMETRYDECK_APP_ID", bundle: testBundle))
        XCTAssertNil(APIKeysReader.string("SENTRY_DSN", bundle: testBundle))
    }

    // MARK: - TelemetryDeckConfiguration

    func testTelemetryDeckConfiguredWithNonEmptyAppID() {
        let config = TelemetryDeckConfiguration(appID: "ABC-123")
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.appID, "ABC-123")
    }

    func testTelemetryDeckNotConfiguredWhenAppIDNil() {
        XCTAssertFalse(TelemetryDeckConfiguration(appID: nil).isConfigured)
    }

    func testTelemetryDeckNotConfiguredWhenAppIDEmpty() {
        XCTAssertFalse(TelemetryDeckConfiguration(appID: "").isConfigured)
    }

    func testTelemetryDeckReadsFromBundleWithoutPlist() {
        // No APIKeys.plist in the test bundle → unconfigured, app falls back to os.Logger analytics.
        let config = TelemetryDeckConfiguration(bundle: Bundle(for: Self.self))
        XCTAssertFalse(config.isConfigured)
    }

    // MARK: - CrashReportingConfiguration

    func testCrashReportingConfiguredWithNonEmptyDSN() {
        let config = CrashReportingConfiguration(dsn: "https://key@example.ingest.sentry.io/1")
        XCTAssertTrue(config.isConfigured)
        XCTAssertEqual(config.dsn, "https://key@example.ingest.sentry.io/1")
    }

    func testCrashReportingNotConfiguredWhenDSNNil() {
        XCTAssertFalse(CrashReportingConfiguration(dsn: nil).isConfigured)
    }

    func testCrashReportingNotConfiguredWhenDSNEmpty() {
        XCTAssertFalse(CrashReportingConfiguration(dsn: "").isConfigured)
    }
}
