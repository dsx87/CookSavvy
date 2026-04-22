//
//  CameraScanTracker.swift
//  CookSavvy
//

import Foundation

/// Tracks the number of AI camera ingredient scans a free-tier user has performed in the current calendar week.
///
/// The week boundary is determined lazily — on each `canScan` / `recordScan` /
/// `remainingScans` call, `resetIfNewWeek()` compares the stored week-of-year and
/// ISO week year against the current date. If they differ, the counter resets to zero and the
/// stored week-start date advances. This means a reset does not happen at a fixed clock
/// time but on the user's **next scan attempt** after a new week begins.
///
/// All state is persisted in `UserDefaults` so counts survive app restarts.
final class CameraScanTracker: CameraScanTrackerProtocol {

    /// Maximum number of AI camera scans permitted per week on the free tier.
    static let freeWeeklyLimit = 5

    /// The UserDefaults store for persisted scan state.
    private let defaults: UserDefaults

    /// Injectable clock for deterministic testing; defaults to `Date()`.
    private let dateProvider: () -> Date

    /// UserDefaults keys for the three persisted values.
    private enum Keys {
        /// Weekly scan counter that resets each new ISO week.
        static let scansUsed = "camera_scans_used_this_week"
        /// The date recorded when the current week's tracking started.
        static let weekStart = "camera_scan_week_start"
        /// Cumulative all-time scan counter, never reset.
        static let totalScans = "camera_scans_total"
    }

    /// Creates a tracker backed by the given UserDefaults store and date provider.
    /// - Parameters:
    ///   - defaults: The `UserDefaults` store to use. Defaults to `.standard`.
    ///   - dateProvider: A closure returning the current date. Defaults to `{ Date() }`.
    init(defaults: UserDefaults = .standard, dateProvider: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.dateProvider = dateProvider
    }

    /// The number of quota-consuming scans performed during the current week.
    private var scansUsedThisWeek: Int {
        get { defaults.integer(forKey: Keys.scansUsed) }
        set { defaults.set(newValue, forKey: Keys.scansUsed) }
    }

    /// The date at which the current week's scan window began.
    ///
    /// On first access the property seeds itself with the current date to establish
    /// a baseline week, ensuring the first scan attempt is never incorrectly rejected.
    private var weekStartDate: Date {
        get {
            if let stored = defaults.object(forKey: Keys.weekStart) as? Date {
                return stored
            }
            let now = dateProvider()
            defaults.set(now, forKey: Keys.weekStart)
            return now
        }
        set { defaults.set(newValue, forKey: Keys.weekStart) }
    }

    /// Resets the weekly counter if the current ISO week/year differs from the stored one.
    ///
    /// Uses `Calendar.current` with `.weekOfYear` and `.yearForWeekOfYear` components so
    /// the reset aligns to the user's locale week boundary rather than a fixed 7-day window.
    private func resetIfNewWeek() {
        let calendar = Calendar.current
        let storedWeek = calendar.component(.weekOfYear, from: weekStartDate)
        let storedYear = calendar.component(.yearForWeekOfYear, from: weekStartDate)
        let currentWeek = calendar.component(.weekOfYear, from: dateProvider())
        let currentYear = calendar.component(.yearForWeekOfYear, from: dateProvider())

        if currentWeek != storedWeek || currentYear != storedYear {
            scansUsedThisWeek = 0
            weekStartDate = dateProvider()
        }
    }

    /// Returns `true` if the user has not yet reached the weekly scan limit.
    ///
    /// Triggers a week-reset check before evaluating.
    /// - Parameter limit: The weekly cap to check against. Defaults to `freeWeeklyLimit`.
    func canScan(limit: Int = freeWeeklyLimit) -> Bool {
        resetIfNewWeek()
        return scansUsedThisWeek < limit
    }

    /// Records one quota-consuming scan, incrementing both the weekly and lifetime counters.
    func recordScan() {
        resetIfNewWeek()
        scansUsedThisWeek += 1
        defaults.set(defaults.integer(forKey: Keys.totalScans) + 1, forKey: Keys.totalScans)
    }

    /// Increments the lifetime total without consuming weekly quota.
    ///
    /// Used for premium users, where scans should be tracked all-time but must not
    /// count against the free-tier weekly cap.
    func recordScanWithoutQuota() {
        defaults.set(defaults.integer(forKey: Keys.totalScans) + 1, forKey: Keys.totalScans)
    }

    /// Returns the cumulative number of scans recorded across all time.
    func totalScansRecorded() -> Int {
        defaults.integer(forKey: Keys.totalScans)
    }

    /// Returns how many quota scans remain this week, floored at zero.
    /// - Parameter limit: The weekly cap to compute against. Defaults to `freeWeeklyLimit`.
    func remainingScans(limit: Int = freeWeeklyLimit) -> Int {
        resetIfNewWeek()
        return max(0, limit - scansUsedThisWeek)
    }
}
