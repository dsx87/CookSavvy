import XCTest
@testable import CookSavvy

final class PantryStaplesTests: XCTestCase {

    @MainActor
    func testKnownStaplesAreStaples() async {
        for name in ["salt", "Salt", " BLACK PEPPER ", "pepper", "cumin", "paprika",
                     "olive oil", "vegetable oil", "sugar", "vinegar", "bay leaf",
                     // Descriptor variants the dataset actually ships (must resolve via word/exact rules).
                     "sea salt", "celery salt", "cayenne pepper", "black peppercorns", "peppercorns",
                     "cumin seeds", "cinnamon stick", "brown sugar", "powdered sugar", "lemon pepper",
                     "fennel seeds", "ground coriander"] {
            XCTAssertTrue(PantryStaples.isStaple(name), "Expected \"\(name)\" to be a staple")
        }
    }

    @MainActor
    func testRealIngredientsAreNotStaples() async {
        // Substantive ingredients, the produce that shares a token with a staple, and the
        // herbs/condiments deliberately kept selectable.
        for name in ["chicken", "tomato", "bell pepper", "chile pepper", "poblano pepper", "rice",
                     "cheddar", "basil", "cilantro", "soy sauce", "pesto", "mustard",
                     "fennel", "sesame oil",
                     // Collisions that must NOT be hidden despite containing a staple word.
                     "salt cod", "sugar snap peas"] {
            XCTAssertFalse(PantryStaples.isStaple(name), "Expected \"\(name)\" to be selectable, not a staple")
        }
    }

    @MainActor
    func testFennelBulbStaysSelectableButFennelSeedIsAStaple() async {
        XCTAssertFalse(PantryStaples.isStaple("fennel"))
        XCTAssertTrue(PantryStaples.isStaple("fennel seeds"))
    }

    @MainActor
    func testPreparedFoodsWithAStapleWordStaySelectable() async {
        // A prepared-food/condiment noun overrides the staple word — these are dishes, not seasonings.
        for name in ["sugar cookie", "sugar cone", "sugar candy bats", "sugar glaze",
                     "saffron mayonnaise", "coconut-turmeric relish", "pomegranate-cumin dressing",
                     "cinnamon syrup", "cardamom elixir"] {
            XCTAssertFalse(PantryStaples.isStaple(name), "Expected \"\(name)\" to be selectable (prepared food)")
        }
        // 'pie' is deliberately NOT a prepared-food word, so pie-spice blends stay staples.
        XCTAssertTrue(PantryStaples.isStaple("pumpkin pie spice"))
    }

    @MainActor
    func testMustardSeedIsStapleButMustardSauceIsNot() async {
        // The dried spice is a staple; the condiment stays a real ingredient.
        XCTAssertTrue(PantryStaples.isStaple("mustard seed"))
        XCTAssertFalse(PantryStaples.isStaple("mustard"))
    }

    @MainActor
    func testExcludingStaplesRemovesOnlyStaplesAndPreservesOrder() async {
        let input = ["Chicken", "Sea Salt", "Bell Pepper", "Cayenne Pepper", "Basil", "Black Peppercorns"]
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
    func testDecodeCatalogBuildsNormalisedRules() async throws {
        // Mirrors the Seasonings.json schema; an unknown extra key (like the file's _comment) is ignored.
        let json = Data("""
        {
          "_comment": "ignored",
          "stapleWords": ["Salt", " CUMIN "],
          "stapleExact": ["Bell Pepper Flakes"],
          "notStaple": ["Salt Cod"],
          "notStapleWords": ["Cookie"]
        }
        """.utf8)

        let catalog = try PantryStaples.decodeCatalog(from: json)

        XCTAssertEqual(catalog.words, ["salt", "cumin"])
        XCTAssertEqual(catalog.exact, ["bell pepper flakes"])
        XCTAssertEqual(catalog.notStaple, ["salt cod"])
        XCTAssertEqual(catalog.notStapleWords, ["cookie"])
    }

    @MainActor
    func testDecodeCatalogToleratesMissingLists() async throws {
        // A partial file still yields a usable catalogue (missing lists default to empty).
        let catalog = try PantryStaples.decodeCatalog(from: Data(#"{ "stapleWords": ["salt"] }"#.utf8))

        XCTAssertEqual(catalog.words, ["salt"])
        XCTAssertTrue(catalog.exact.isEmpty)
        XCTAssertTrue(catalog.notStaple.isEmpty)
        XCTAssertTrue(catalog.notStapleWords.isEmpty)
    }
}
