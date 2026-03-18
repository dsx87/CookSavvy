import Foundation

protocol CameraScanTrackerProtocol: AnyObject {
    func canScan(limit: Int) -> Bool
    func recordScan()
    func recordScanWithoutQuota()
    func remainingScans(limit: Int) -> Int
    func totalScansRecorded() -> Int
}

extension CameraScanTrackerProtocol {
    func canScan() -> Bool {
        canScan(limit: CameraScanTracker.freeWeeklyLimit)
    }

    func remainingScans() -> Int {
        remainingScans(limit: CameraScanTracker.freeWeeklyLimit)
    }
}
