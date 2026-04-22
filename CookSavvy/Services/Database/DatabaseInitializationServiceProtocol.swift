import Foundation

/// Protocol describing the database initialisation lifecycle observable by the rest of the app.
///
/// Conformers drive the two-phase startup sequence (ingredients first, then recipes) and
/// expose the current `state` for progress tracking. `AppContainer` uses this protocol
/// to await readiness before vending services that depend on seeded data.
protocol DatabaseInitializationServiceProtocol: AnyObject {
    /// The current phase of the initialisation sequence.
    var state: DatabaseInitializationState { get }

    /// Begins the two-phase initialisation sequence asynchronously.
    /// Safe to call multiple times; subsequent calls are no-ops if initialisation is already in progress.
    func startInitialization()

    /// Suspends the caller until the ingredients phase completes (or fails).
    /// Returns immediately if state has already progressed past `loadingIngredients`.
    func waitForIngredients() async

    /// Suspends the caller until the full initialisation sequence completes (or fails).
    /// Returns immediately if state is already `.ready`.
    func waitForRecipes() async

    #if DEBUG
    /// Cancels any in-progress initialisation and forces state to `.ready`.
    /// Used by unit tests to bypass real data loading.
    func markReadyForTesting()
    #endif
}
