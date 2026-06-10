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
        XCTAssertEqual(tracker.remainingScans(), CameraScanTracker.freeWeeklyLimit - 1)
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
        let customLimit = 2
        let tracker = makeTracker()
        for _ in 0..<customLimit {
            tracker.recordScan()
        }
        XCTAssertFalse(tracker.canScan(limit: customLimit))
        XCTAssertEqual(tracker.remainingScans(limit: customLimit), 0)
    }

    func testRollingWindowClearsAfterSevenDays() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let tracker = CameraScanTracker(defaults: defaults, dateProvider: { baseDate })
        for _ in 0..<CameraScanTracker.freeWeeklyLimit {
            tracker.recordScan()
        }
        XCTAssertFalse(tracker.canScan())

        // Just past 7 days later: every stored timestamp falls outside the rolling window → restored.
        let afterWindow = baseDate.addingTimeInterval(7 * 24 * 3600 + 1)
        let laterTracker = CameraScanTracker(defaults: defaults, dateProvider: { afterWindow })
        XCTAssertTrue(laterTracker.canScan())
        XCTAssertEqual(laterTracker.remainingScans(), CameraScanTracker.freeWeeklyLimit)
    }

    func testRollingWindowDoesNotClearBeforeSevenDays() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let tracker = CameraScanTracker(defaults: defaults, dateProvider: { baseDate })
        for _ in 0..<CameraScanTracker.freeWeeklyLimit {
            tracker.recordScan()
        }
        XCTAssertFalse(tracker.canScan())

        // Still inside the window (6 days later) → quota remains exhausted.
        let withinWindow = baseDate.addingTimeInterval(6 * 24 * 3600)
        let laterTracker = CameraScanTracker(defaults: defaults, dateProvider: { withinWindow })
        XCTAssertFalse(laterTracker.canScan())
        XCTAssertEqual(laterTracker.remainingScans(), 0)
    }

    func testRollingWindowExpiresOldestScanFirst() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let day0 = CameraScanTracker(defaults: defaults, dateProvider: { baseDate })
        day0.recordScan()

        // Two more scans three days later — three in the window, so the gate is closed.
        let day3Date = baseDate.addingTimeInterval(3 * 24 * 3600)
        let day3 = CameraScanTracker(defaults: defaults, dateProvider: { day3Date })
        day3.recordScan()
        day3.recordScan()
        XCTAssertFalse(day3.canScan())

        // Day 8: only the day-0 scan has aged out; the two day-3 scans remain → one slot free.
        let day8Date = baseDate.addingTimeInterval(8 * 24 * 3600)
        let day8 = CameraScanTracker(defaults: defaults, dateProvider: { day8Date })
        XCTAssertTrue(day8.canScan())
        XCTAssertEqual(day8.remainingScans(), 1)
    }

    func testOverLimitDoesNotGoNegative() {
        let tracker = makeTracker()
        for _ in 0..<10 {
            tracker.recordScan()
        }
        XCTAssertGreaterThanOrEqual(tracker.remainingScans(), 0)
    }
}
