import XCTest
@testable import CookSavvy

final class PantryStaplesTests: XCTestCase {

    @MainActor
    func testKnownStaplesAreStaples() async {
        for name in ["salt", "Salt", " BLACK PEPPER ", "pepper", "cumin", "paprika",
                     "olive oil", "vegetable oil", "sugar", "vinegar", "bay leaf"] {
            XCTAssertTrue(PantryStaples.isStaple(name), "Expected \"\(name)\" to be a staple")
        }
    }

    @MainActor
    func testRealIngredientsAreNotStaples() async {
        // Substantive ingredients — and the herbs/condiments deliberately kept selectable.
        for name in ["chicken", "tomato", "bell pepper", "rice", "cheddar",
                     "basil", "cilantro", "soy sauce", "pesto", "mustard"] {
            XCTAssertFalse(PantryStaples.isStaple(name), "Expected \"\(name)\" to be selectable, not a staple")
        }
    }

    @MainActor
    func testMustardSeedIsStapleButMustardSauceIsNot() async {
        // The dried spice is a staple; the condiment stays a real ingredient.
        XCTAssertTrue(PantryStaples.isStaple("mustard seed"))
        XCTAssertFalse(PantryStaples.isStaple("mustard"))
    }

    @MainActor
    func testExcludingStaplesRemovesOnlyStaplesAndPreservesOrder() async {
        let input = ["Chicken", "Salt", "Bell Pepper", "Cumin", "Basil", "Pepper"]
            .map(Ingredient.init(name:))

        let result = PantryStaples.excludingStaples(input).map(\.name)

        XCTAssertEqual(result, ["Chicken", "Bell Pepper", "Basil"])
    }

    @MainActor
    func testEmptyAndUnknownNamesAreNotStaples() async {
        XCTAssertFalse(PantryStaples.isStaple(""))
        XCTAssertFalse(PantryStaples.isStaple("   "))
        XCTAssertFalse(PantryStaples.isStaple("zzzqqq"))
    }

    @MainActor
    func testDecodeNamesFlattensGroupsAndNormalises() async throws {
        // Mirrors the Seasonings.json schema: group name → names, flattened and normalised.
        let json = Data("""
        { "basics": ["Salt", " PEPPER "], "driedSpices": ["cumin"] }
        """.utf8)

        let names = try PantryStaples.decodeNames(from: json)

        XCTAssertEqual(names, ["salt", "pepper", "cumin"])
    }
}
