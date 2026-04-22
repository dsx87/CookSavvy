import Foundation

protocol DatabaseInitializationServiceProtocol: AnyObject {
    var state: DatabaseInitializationState { get }
    func startInitialization()
    func waitForIngredients() async
    func waitForRecipes() async

    #if DEBUG
    func markReadyForTesting()
    #endif
}
