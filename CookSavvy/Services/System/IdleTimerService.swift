import UIKit

/// Production `IdleTimerServiceProtocol` backed by `UIApplication.shared.isIdleTimerDisabled`.
///
/// Setting the flag is a global UIKit side effect, so this service holds no state of its
/// own — the single shared instance simply forwards the request to the active application.
final class IdleTimerService: IdleTimerServiceProtocol {
    // Stateless, so the initializer is nonisolated — this lets it be used as a default
    // argument value (evaluated in a nonisolated context) in `AppContainer`'s DEBUG init.
    nonisolated init() {}

    func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}
