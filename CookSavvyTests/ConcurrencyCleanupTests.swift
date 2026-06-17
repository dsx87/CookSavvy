import XCTest
import UIKit
@testable import CookSavvy

// MARK: - AIIngredientDetectionAdapter (B1)

/// Verifies the adapter still maps AI errors correctly and forwards a non-empty encoded payload now
/// that the downscale + JPEG encode runs off the main actor via `Task { @concurrent in … }`.
@MainActor
final class AIIngredientDetectionAdapterTests: XCTestCase {

    private func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }

    func testDetectForwardsEncodedDataAndReturnsIngredients() async throws {
        let ai = StubAIService()
        ai.stubbedIngredients = [Ingredient(name: "Tomato")]
        let adapter = AIIngredientDetectionAdapter(aiService: ai)

        let result = try await adapter.detectIngredients(in: makeImage())

        XCTAssertEqual(result.map(\.name), ["Tomato"])
        XCTAssertFalse(ai.receivedImageData?.isEmpty ?? true, "Adapter should pass non-empty JPEG data")
    }

    func testNoIngredientsDetectedMapsThrough() async {
        let ai = StubAIService()
        ai.errorToThrow = .noIngredientsDetected
        let adapter = AIIngredientDetectionAdapter(aiService: ai)

        await assertThrows(adapter, expected: .noIngredientsDetected)
    }

    func testInvalidImageDataMapsToInvalidImage() async {
        let ai = StubAIService()
        ai.errorToThrow = .invalidImageData
        let adapter = AIIngredientDetectionAdapter(aiService: ai)

        await assertThrows(adapter, expected: .invalidImage)
    }

    func testOtherAIErrorMapsToProcessingFailed() async {
        let ai = StubAIService()
        ai.errorToThrow = .noProviderConfigured
        let adapter = AIIngredientDetectionAdapter(aiService: ai)

        do {
            _ = try await adapter.detectIngredients(in: makeImage())
            XCTFail("Expected processingFailed")
        } catch let error as IngredientDetectionError {
            guard case .processingFailed = error else {
                return XCTFail("Expected processingFailed, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    private func assertThrows(
        _ adapter: AIIngredientDetectionAdapter,
        expected: IngredientDetectionError,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await adapter.detectIngredients(in: makeImage())
            XCTFail("Expected throw", file: file, line: line)
        } catch let error as IngredientDetectionError {
            switch (error, expected) {
            case (.noIngredientsDetected, .noIngredientsDetected), (.invalidImage, .invalidImage):
                break
            default:
                XCTFail("Expected \(expected), got \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("Unexpected error type: \(error)", file: file, line: line)
        }
    }
}

private final class StubAIService: AIServiceProtocol {
    var isAvailable = true
    var stubbedIngredients: [Ingredient] = []
    var errorToThrow: AIServiceError?
    private(set) var receivedImageData: Data?

    func detectIngredients(from imageData: Data) async throws -> [Ingredient] {
        receivedImageData = imageData
        if let errorToThrow { throw errorToThrow }
        return stubbedIngredients
    }

    func generateRecipes(for ingredients: [Ingredient], count: Int) async throws -> [Recipe] { [] }
}

// MARK: - DataImportService import guard (Part C)

/// Verifies the documented in-memory short-circuit: once a call has confirmed recipes are imported,
/// a second call returns immediately without re-probing the database.
final class DataImportServiceGuardTests: XCTestCase {

    func testSecondCallShortCircuitsViaInMemoryFlag() async throws {
        let db = StubImportStore()
        // Make the first call take the "already imported in DB" early-return path, which sets the flag.
        db.stubbedIngredients = [Ingredient(name: "Chicken")]
        db.stubbedRecipesByIngredients = [Recipe(title: "Existing", ingredients: [], instructions: ["Step"],
                                                 image: "", additionalInfo: .empty)]
        let service = DataImportService(dbInterface: db, logger: MockLogger())

        try await service.ensureRecipesImported()
        XCTAssertEqual(db.searchIngredientsCallCount, 1)

        try await service.ensureRecipesImported()
        XCTAssertEqual(db.searchIngredientsCallCount, 1,
                       "Second call should short-circuit on isRecipesImported without re-probing the DB")
    }
}

/// Minimal `IngredientStoreProtocol & RecipeStoreProtocol` stub for the import-guard test.
private final class StubImportStore: IngredientStoreProtocol, RecipeStoreProtocol {
    var stubbedIngredients: [Ingredient] = []
    var stubbedRecipesByIngredients: [Recipe] = []
    private(set) var searchIngredientsCallCount = 0

    // IngredientStoreProtocol
    func searchIngredients(matching query: String, limit: Int) async throws -> [Ingredient] {
        searchIngredientsCallCount += 1
        return stubbedIngredients
    }
    func getIngredients(byName name: String) async throws -> [Ingredient] { [] }
    func insertIngredients(_ ingredients: [Ingredient]) async throws {}
    func removeIngredients(_ ingredients: [Ingredient]) async throws {}
    func getAllIngredients(inGroup foodGroup: String?, limit: Int) async throws -> [Ingredient] { [] }
    func getDistinctFoodGroups() async throws -> [String] { [] }

    // RecipeStoreProtocol
    func getRecipes(byIngredients: [Ingredient], offset: Int, limit: Int) async throws -> [Recipe] {
        stubbedRecipesByIngredients
    }
    func getAllRecipes(offset: Int, limit: Int) async throws -> [Recipe] { [] }
    func getRecipeId(byTitle title: String) async throws -> Int? { nil }
    func getRecipe(byID id: Int) async throws -> Recipe? { nil }
    func insertRecipes(_ recipes: [Recipe]) async throws {}
    func removeRecipes(_ recipes: [Recipe]) async throws {}
}
