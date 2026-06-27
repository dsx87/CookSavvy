//
//  LoggingServiceCrashSinkTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

/// Verifies that loggers created by `LoggingService` forward error/fault entries to the injected
/// crash reporter as breadcrumbs (and faults as captured errors), while lower severities do not.
final class LoggingServiceCrashSinkTests: XCTestCase {

    private var crashSink: MockCrashReportingService!
    private var logger: LoggerProtocol!

    @MainActor
    override func setUp() async throws {
        crashSink = MockCrashReportingService()
        logger = LoggingService(crashSink: crashSink).makeLogger(category: .recipeService)
    }

    @MainActor
    override func tearDown() async throws {
        logger = nil
        crashSink = nil
    }

    @MainActor
    func testLowSeverityLogsDoNotForward() async {
        logger.debug("d")
        logger.info("i")
        logger.notice("n")

        XCTAssertTrue(crashSink.breadcrumbs.isEmpty)
        XCTAssertTrue(crashSink.recordedErrors.isEmpty)
    }

    @MainActor
    func testWarningForwardsWarningBreadcrumbOnly() async {
        logger.warning("disk almost full")

        XCTAssertEqual(crashSink.breadcrumbs.count, 1)
        XCTAssertEqual(crashSink.breadcrumbs.first?.level, .warning)
        XCTAssertEqual(crashSink.breadcrumbs.first?.message, "[RecipeService] disk almost full")
        XCTAssertTrue(crashSink.recordedErrors.isEmpty)
    }

    @MainActor
    func testErrorCapturesNonFatalEvent() async {
        logger.error("query failed")

        XCTAssertEqual(crashSink.recordedErrors.count, 1)
        XCTAssertEqual(
            crashSink.recordedErrors.first?.localizedDescription,
            "[RecipeService] query failed"
        )
        XCTAssertTrue(crashSink.breadcrumbs.isEmpty)
    }

    @MainActor
    func testFaultCapturesNonFatalEvent() async {
        logger.fault("invariant broken")

        XCTAssertEqual(crashSink.recordedErrors.count, 1)
        XCTAssertEqual(
            crashSink.recordedErrors.first?.localizedDescription,
            "[RecipeService] invariant broken"
        )
        XCTAssertTrue(crashSink.breadcrumbs.isEmpty)
    }

    @MainActor
    func testNilCrashSinkIsHarmless() async {
        // A logger built without a sink must still log without crashing or forwarding.
        let sinkless = LoggingService().makeLogger(category: .recipeService)
        sinkless.error("no sink")
        XCTAssertTrue(crashSink.breadcrumbs.isEmpty)
        XCTAssertTrue(crashSink.recordedErrors.isEmpty)
    }
}
