import XCTest
@testable import CookSavvy

final class DatabaseInitializationServiceTests: XCTestCase {

    func testMarkReadyForTestingSetsReadyState() {
        let service = DatabaseInitializationService(
            dbInterface: DBInterface(inMemory: true),
            ingredientsService: MockIngredientsService(),
            dataImportService: MockDataImportService()
        )

        service.markReadyForTesting()

        XCTAssertEqual(service.state, .ready)
    }
}

private final class MockDataImportService: DataImportServiceProtocol {
    func ensureRecipesImported() async throws {}
    func forceReimportRecipes() async throws {}
}
