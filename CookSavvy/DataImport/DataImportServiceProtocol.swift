import Foundation

protocol DataImportServiceProtocol: AnyObject {
    func ensureRecipesImported() async throws
    func forceReimportRecipes() async throws
}
