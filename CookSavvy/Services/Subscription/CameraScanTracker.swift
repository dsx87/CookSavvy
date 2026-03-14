//
//  CameraScanTracker.swift
//  CookSavvy
//

import Foundation

final class CameraScanTracker {

    static let freeWeeklyLimit = 5

    private let defaults = UserDefaults.standard
    private let scansUsedKey = "camera_scans_used_this_week"
    private let weekStartKey = "camera_scan_week_start"

    private var scansUsedThisWeek: Int {
        get { defaults.integer(forKey: scansUsedKey) }
        set { defaults.set(newValue, forKey: scansUsedKey) }
    }

    private var weekStartDate: Date {
        get {
            if let stored = defaults.object(forKey: weekStartKey) as? Date {
                return stored
            }
            let now = Date()
            defaults.set(now, forKey: weekStartKey)
            return now
        }
        set { defaults.set(newValue, forKey: weekStartKey) }
    }

    private func resetIfNewWeek() {
        let calendar = Calendar.current
        let storedWeek = calendar.component(.weekOfYear, from: weekStartDate)
        let storedYear = calendar.component(.yearForWeekOfYear, from: weekStartDate)
        let currentWeek = calendar.component(.weekOfYear, from: Date())
        let currentYear = calendar.component(.yearForWeekOfYear, from: Date())

        if currentWeek != storedWeek || currentYear != storedYear {
            scansUsedThisWeek = 0
            weekStartDate = Date()
        }
    }

    func canScan(limit: Int = freeWeeklyLimit) -> Bool {
        resetIfNewWeek()
        return scansUsedThisWeek < limit
    }

    func recordScan() {
        resetIfNewWeek()
        scansUsedThisWeek += 1
    }

    func remainingScans(limit: Int = freeWeeklyLimit) -> Int {
        resetIfNewWeek()
        return max(0, limit - scansUsedThisWeek)
    }
}
