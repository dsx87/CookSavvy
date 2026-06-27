import XCTest
@testable import CookSavvy

final class IngredientCategoryClassifierTests: XCTestCase {

    @MainActor
    func testRepresentativeNamesMapToExpectedCategories() async {
        let cases: [(name: String, expected: IngredientCategory)] = [
            ("chicken", .proteins),
            ("salmon", .proteins),
            ("egg", .proteins),
            ("tofu", .proteins),
            ("tomato", .veggies),
            ("onion", .veggies),
            ("garlic", .veggies),
            ("chickpeas", .veggies),
            ("cheddar", .dairy),
            ("milk", .dairy),
            ("butter", .dairy),
            ("basmati rice", .grains),
            ("spaghetti", .grains),
            ("flour", .grains),
            ("blueberry", .fruits),
            ("apple", .fruits),
            ("lemon", .fruits),
            ("cumin", .spices),
            ("black pepper", .spices),
            ("basil", .spices)
        ]

        for testCase in cases {
            XCTAssertEqual(
                IngredientCategoryClassifier.category(forName: testCase.name),
                testCase.expected,
                "Expected \"\(testCase.name)\" to classify as \(testCase.expected)"
            )
        }
    }

    @MainActor
    func testPluralAndAdjectiveFormsResolve() async {
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "tomatoes"), .veggies)
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "potatoes"), .veggies)
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "fresh strawberries"), .fruits)
    }

    @MainActor
    func testPriorityResolvesOverlaps() async {
        // Nuts (proteins) are checked before dairy's "butter".
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "peanut butter"), .proteins)
        // "bell pepper" is produce, not the "pepper" seasoning.
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "bell pepper"), .veggies)
    }

    @MainActor
    func testUnrecognizedAndEmptyNamesFallBackToOther() async {
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "zzzqqq"), .other)
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: ""), .other)
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "   "), .other)
    }

    @MainActor
    func testShortKeywordDoesNotFalseMatchLongerWord() async {
        // "egg" (3 letters) must not match "eggplant", which is a vegetable.
        XCTAssertEqual(IngredientCategoryClassifier.category(forName: "eggplant"), .veggies)
    }
}
