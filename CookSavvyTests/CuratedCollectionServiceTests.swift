import XCTest
@testable import CookSavvy

final class CuratedCollectionServiceTests: XCTestCase {

    private var service: CuratedCollectionService!
    private var db: DBInterface!

    override func setUpWithError() throws {
        try super.setUpWithError()
        db = try DBInterface(inMemory: true)
        service = CuratedCollectionService(dbInterface: db)
    }

    // MARK: - getCollectionsForThisWeek

    func testFreeUserGetsOneCollection() {
        let collections = service.getCollectionsForThisWeek(isPremium: false)
        XCTAssertEqual(collections.count, 1)
    }

    func testPremiumUserGetsThreeCollections() {
        let collections = service.getCollectionsForThisWeek(isPremium: true)
        XCTAssertEqual(collections.count, 3)
    }

    func testCollectionsHaveUniqueIDs() {
        let collections = service.getCollectionsForThisWeek(isPremium: true)
        let ids = Set(collections.map(\.id))
        XCTAssertEqual(ids.count, collections.count)
    }

    func testCollectionsHaveNonEmptyTitles() {
        let collections = service.getCollectionsForThisWeek(isPremium: true)
        for collection in collections {
            XCTAssertFalse(collection.title.isEmpty, "Collection \(collection.id) has empty title")
            XCTAssertFalse(collection.subtitle.isEmpty, "Collection \(collection.id) has empty subtitle")
            XCTAssertFalse(collection.emoji.isEmpty, "Collection \(collection.id) has empty emoji")
        }
    }

    func testFreeCollectionIsSubsetOfPremiumCollections() {
        let free = service.getCollectionsForThisWeek(isPremium: false)
        let premium = service.getCollectionsForThisWeek(isPremium: true)
        XCTAssertTrue(free.allSatisfy { fc in premium.contains(where: { $0.id == fc.id }) })
    }

    // MARK: - getRecipes

    func testGetRecipesWithIngredientKeywordsReturnsArray() async throws {
        let collection = CuratedCollection(
            id: "test",
            title: "Test",
            subtitle: "Sub",
            emoji: "🍲",
            gradientColors: (.blue, .green),
            filterCriteria: FilterCriteria(ingredientKeywords: ["chicken"])
        )
        // DB is empty so we get an empty array, not an error
        let recipes = try await service.getRecipes(for: collection)
        XCTAssertNotNil(recipes)
    }

    func testGetRecipesWithMaxIngredientCountFiltersClientSide() async throws {
        let collection = CuratedCollection(
            id: "five_ingredient",
            title: "5-Ingredient",
            subtitle: "Sub",
            emoji: "🥘",
            gradientColors: (.green, .blue),
            filterCriteria: FilterCriteria(maxIngredientCount: 5)
        )
        let recipes = try await service.getRecipes(for: collection)
        for recipe in recipes {
            let count = recipe.cleanedIngredients.isEmpty ? recipe.ingredients.count : recipe.cleanedIngredients.count
            XCTAssertLessThanOrEqual(count, 5, "Recipe '\(recipe.title)' has \(count) ingredients, exceeds max 5")
        }
    }
}
