import Foundation

/// Interface for tracking and enforcing the free-tier weekly camera scan quota.
///
/// Concrete implementations persist state between calls so quota checks survive
/// app restarts. The weekly window resets lazily on the caller's next interaction
/// after a new ISO week begins, rather than at a fixed clock time.
protocol CameraScanTrackerProtocol: AnyObject {
    /// Returns `true` if the user has not yet consumed `limit` scans this week.
    /// - Parameter limit: The weekly quota ceiling.
    func canScan(limit: Int) -> Bool

    /// Records one quota-consuming scan, incrementing weekly and lifetime counters.
    func recordScan()

    /// Increments the lifetime scan total without consuming weekly quota.
    /// Used for premium users whose scans should not count against the free cap.
    func recordScanWithoutQuota()

    /// Returns how many quota scans remain this week.
    /// - Parameter limit: The weekly quota ceiling.
    func remainingScans(limit: Int) -> Int

    /// Returns the cumulative total of all scans recorded across all time.
    func totalScansRecorded() -> Int
}

/// Convenience overloads that default to `CameraScanTracker.freeWeeklyLimit`.
extension CameraScanTrackerProtocol {
    /// Returns `true` if the user has scans remaining under the default free-tier limit.
    func canScan() -> Bool {
        canScan(limit: CameraScanTracker.freeWeeklyLimit)
    }

    /// Returns the number of scans remaining under the default free-tier limit.
    func remainingScans() -> Int {
        remainingScans(limit: CameraScanTracker.freeWeeklyLimit)
    }
}
