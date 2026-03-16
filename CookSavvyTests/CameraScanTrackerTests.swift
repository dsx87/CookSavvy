//
//  CameraScanTrackerTests.swift
//  CookSavvyTests
//

import XCTest
@testable import CookSavvy

final class CameraScanTrackerTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "com.cooksavvy.tests.camerascantracker"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeTracker(date: Date = Date()) -> CameraScanTracker {
        CameraScanTracker(defaults: defaults, dateProvider: { date })
    }

    func testFreshStateAllowsScans() {
        let tracker = makeTracker()
        XCTAssertTrue(tracker.canScan())
        XCTAssertEqual(tracker.remainingScans(), CameraScanTracker.freeWeeklyLimit)
    }

    func testRecordingDecrementsRemaining() {
        let tracker = makeTracker()
        tracker.recordScan()
        tracker.recordScan()
        tracker.recordScan()
        XCTAssertEqual(tracker.remainingScans(), CameraScanTracker.freeWeeklyLimit - 3)
    }

    func testLimitReachedBlocksScans() {
        let tracker = makeTracker()
        for _ in 0..<CameraScanTracker.freeWeeklyLimit {
            tracker.recordScan()
        }
        XCTAssertFalse(tracker.canScan())
        XCTAssertEqual(tracker.remainingScans(), 0)
    }

    func testCustomLimit() {
        let customLimit = 3
        let tracker = makeTracker()
        for _ in 0..<customLimit {
            tracker.recordScan()
        }
        XCTAssertFalse(tracker.canScan(limit: customLimit))
        XCTAssertEqual(tracker.remainingScans(limit: customLimit), 0)
    }

    func testWeekResetRestoresScans() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let thisWeekTracker = CameraScanTracker(defaults: defaults, dateProvider: { baseDate })
        for _ in 0..<CameraScanTracker.freeWeeklyLimit {
            thisWeekTracker.recordScan()
        }
        XCTAssertFalse(thisWeekTracker.canScan())

        // Advance to next week (8 days later)
        let nextWeekDate = baseDate.addingTimeInterval(8 * 24 * 3600)
        let nextWeekTracker = CameraScanTracker(defaults: defaults, dateProvider: { nextWeekDate })
        XCTAssertTrue(nextWeekTracker.canScan())
        XCTAssertEqual(nextWeekTracker.remainingScans(), CameraScanTracker.freeWeeklyLimit)
    }

    func testOverLimitDoesNotGoNegative() {
        let tracker = makeTracker()
        for _ in 0..<10 {
            tracker.recordScan()
        }
        XCTAssertGreaterThanOrEqual(tracker.remainingScans(), 0)
    }
}
