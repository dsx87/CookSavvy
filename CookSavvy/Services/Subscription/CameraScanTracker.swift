//
//  CameraScanTracker.swift
//  CookSavvy
//

import Foundation

/// Tracks the AI camera ingredient scans a free-tier user has performed within a rolling 7-day window.
///
/// This is a faithful mirror of the backend rate limiter (`_shared/rate-limit.ts`), which counts
/// `api_usage` rows in a rolling `window_hours` window — 168h (7 days) for free `detect-ingredients`.
/// Each quota-consuming scan stores its timestamp; on every quota query the tracker prunes
/// timestamps older than `dateProvider() − 7d` and counts what remains. A rolling window (rather
/// than a calendar/ISO week) is required so the local badge and pre-camera gate never contradict the
/// server at a week boundary: a calendar week would reset on Monday while the backend still 429s
/// until 7 days after the user's oldest scan.
///
/// All state is persisted in `UserDefaults` so counts survive app restarts.
final class CameraScanTracker: CameraScanTrackerProtocol {

    /// Maximum number of AI camera scans permitted per rolling 7-day window on the free tier.
    static let freeWeeklyLimit = 3

    /// Length of the rolling quota window, in seconds (7 days) — matches the backend's 168h window.
    private static let windowDuration: TimeInterval = 7 * 24 * 60 * 60

    /// The UserDefaults store for persisted scan state.
    private let defaults: UserDefaults

    /// Injectable clock for deterministic testing; defaults to `Date()`.
    private let dateProvider: () -> Date

    /// UserDefaults keys for the persisted values.
    private enum Keys {
        /// Timestamps of quota-consuming scans inside the rolling window; pruned on each access.
        static let scanTimestamps = "camera_scan_timestamps"
        /// Cumulative all-time scan counter, never reset (drives the `scan_pro` achievement).
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

    /// The quota-consuming scan timestamps currently persisted (before pruning).
    ///
    /// `Date` is a property-list type, so the array round-trips through `UserDefaults` directly.
    private var storedTimestamps: [Date] {
        get { (defaults.array(forKey: Keys.scanTimestamps) as? [Date]) ?? [] }
        set { defaults.set(newValue, forKey: Keys.scanTimestamps) }
    }

    /// Drops timestamps older than the rolling window and returns those still inside it.
    ///
    /// Persists the pruned array when anything was removed so the store cannot grow unbounded.
    /// Mirrors the backend's `since = now − window_hours` filter on `api_usage`.
    @discardableResult
    private func pruneWindow() -> [Date] {
        let cutoff = dateProvider().addingTimeInterval(-Self.windowDuration)
        let recent = storedTimestamps.filter { $0 > cutoff }
        if recent.count != storedTimestamps.count {
            storedTimestamps = recent
        }
        return recent
    }

    /// Returns `true` if fewer than `limit` scans fall within the rolling 7-day window.
    /// - Parameter limit: The window cap to check against. Defaults to `freeWeeklyLimit`.
    func canScan(limit: Int = freeWeeklyLimit) -> Bool {
        pruneWindow().count < limit
    }

    /// Records one quota-consuming scan, appending its timestamp and bumping the lifetime total.
    func recordScan() {
        var recent = pruneWindow()
        recent.append(dateProvider())
        storedTimestamps = recent
        defaults.set(defaults.integer(forKey: Keys.totalScans) + 1, forKey: Keys.totalScans)
    }

    /// Increments the lifetime total without consuming window quota.
    ///
    /// Used for premium users, whose scans should be tracked all-time but must not count against
    /// the free-tier window cap.
    func recordScanWithoutQuota() {
        defaults.set(defaults.integer(forKey: Keys.totalScans) + 1, forKey: Keys.totalScans)
    }

    /// Returns the cumulative number of scans recorded across all time.
    func totalScansRecorded() -> Int {
        defaults.integer(forKey: Keys.totalScans)
    }

    /// Returns how many quota scans remain in the rolling window, floored at zero.
    /// - Parameter limit: The window cap to compute against. Defaults to `freeWeeklyLimit`.
    func remainingScans(limit: Int = freeWeeklyLimit) -> Int {
        max(0, limit - pruneWindow().count)
    }
}
