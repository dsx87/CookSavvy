//
//  CameraScanTracker.swift
//  CookSavvy
//

import Foundation

final class CameraScanTracker: CameraScanTrackerProtocol {

    static let freeWeeklyLimit = 5

    private let defaults: UserDefaults
    private let dateProvider: () -> Date

    private enum Keys {
        static let scansUsed = "camera_scans_used_this_week"
        static let weekStart = "camera_scan_week_start"
        static let totalScans = "camera_scans_total"
    }

    init(defaults: UserDefaults = .standard, dateProvider: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.dateProvider = dateProvider
    }

    private var scansUsedThisWeek: Int {
        get { defaults.integer(forKey: Keys.scansUsed) }
        set { defaults.set(newValue, forKey: Keys.scansUsed) }
    }

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

    func canScan(limit: Int = freeWeeklyLimit) -> Bool {
        resetIfNewWeek()
        return scansUsedThisWeek < limit
    }

    func recordScan() {
        resetIfNewWeek()
        scansUsedThisWeek += 1
        defaults.set(defaults.integer(forKey: Keys.totalScans) + 1, forKey: Keys.totalScans)
    }

    func recordScanWithoutQuota() {
        defaults.set(defaults.integer(forKey: Keys.totalScans) + 1, forKey: Keys.totalScans)
    }

    func totalScansRecorded() -> Int {
        defaults.integer(forKey: Keys.totalScans)
    }

    func remainingScans(limit: Int = freeWeeklyLimit) -> Int {
        resetIfNewWeek()
        return max(0, limit - scansUsedThisWeek)
    }
}
