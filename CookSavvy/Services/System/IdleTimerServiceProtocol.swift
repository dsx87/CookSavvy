import Foundation

/// Controls the system idle timer that dims and locks the screen after inactivity.
///
/// Cook Mode is a hands-free kitchen screen: the user often can't touch the phone for
/// minutes at a time, so the screen must be kept awake while cooking. Implementations
/// wrap `UIApplication.isIdleTimerDisabled` behind this protocol so the behaviour can be
/// mocked in tests and DEBUG builds.
protocol IdleTimerServiceProtocol: AnyObject {
    /// Disables (`true`) or re-enables (`false`) the system idle timer.
    ///
    /// Callers must balance every `true` with a matching `false` so the idle timer is
    /// not left disabled after the screen that needed it goes away.
    func setIdleTimerDisabled(_ disabled: Bool)
}
