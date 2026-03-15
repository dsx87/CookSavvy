import Foundation

protocol CameraScanTrackerProtocol: AnyObject {
    func canScan(limit: Int) -> Bool
    func recordScan()
    func remainingScans(limit: Int) -> Int
}

extension CameraScanTrackerProtocol {
    func canScan() -> Bool {
        canScan(limit: CameraScanTracker.freeWeeklyLimit)
    }

    func remainingScans() -> Int {
        remainingScans(limit: CameraScanTracker.freeWeeklyLimit)
    }
}
