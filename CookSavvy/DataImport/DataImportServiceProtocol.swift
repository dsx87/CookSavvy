import Foundation

/// Defines recipe dataset import lifecycle operations used during app startup and recovery flows.
protocol DataImportServiceProtocol: AnyObject {
    /// Imports the bundled recipe dataset when no previous successful import marker is found.
    func ensureRecipesImported() async throws
    /// Clears import bookkeeping and forces a full re-import of the bundled dataset.
    func forceReimportRecipes() async throws
}
