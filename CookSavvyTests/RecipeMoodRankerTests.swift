import XCTest
@testable import CookSavvy

final class RecipeMoodRankerTests: XCTestCase {

    private func makeRecipe(
        title: String,
        tagline: String? = nil,
        cuisine: String? = nil,
        ingredientNames: [String] = [],
        time: String? = nil,
        complexity: String? = nil
    ) -> Recipe {
        let ingredients = ingredientNames.map { Ingredient(stringLiteral: $0) }
        let info = Recipe.AdditionalInfo(
            time: time,
            servings: nil,
            complexity: complexity,
            calories: nil
        )
        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: [Recipe.Step(text: "Cook.")],
            image: "",
            cleanedIngredients: ingredients,
            additionalInfo: info,
            tagline: tagline,
            cuisine: cuisine
        )
    }

    func testCozyMoodRanksWarmKeywordsFirst() {
        let soup = makeRecipe(title: "Warm Chicken Soup")
        let salad = makeRecipe(title: "Fresh Avocado Salad")
        let ranked = RecipeMoodRanker.rank([salad, soup], for: .cozy)
        XCTAssertEqual(ranked.first?.title, soup.title)
    }

    func testQuickMoodPrefersShortCookTime() {
        let fast = makeRecipe(title: "Quick Stir Fry", time: "10 min")
        let slow = makeRecipe(title: "Slow Roast", time: "45 min")
        let ranked = RecipeMoodRanker.rank([slow, fast], for: .quick)
        XCTAssertEqual(ranked.first?.title, fast.title)
    }

    func testQuickMoodPrefersEasyComplexity() {
        let easy = makeRecipe(title: "Simple Bowl", complexity: "Easy")
        let medium = makeRecipe(title: "Medium Bowl", complexity: "Medium")
        let ranked = RecipeMoodRanker.rank([medium, easy], for: .quick)
        XCTAssertEqual(ranked.first?.title, easy.title)
    }

    func testBoldMoodGivesCuisineBonusForThai() {
        let thai = makeRecipe(title: "Noodle Dish", cuisine: "Thai")
        let plain = makeRecipe(title: "Noodle Dish 2")
        let ranked = RecipeMoodRanker.rank([plain, thai], for: .bold)
        XCTAssertEqual(ranked.first?.title, thai.title)
    }

    func testStableSortPreservesOrderOnTie() {
        let r1 = makeRecipe(title: "Recipe A")
        let r2 = makeRecipe(title: "Recipe B")
        let r3 = makeRecipe(title: "Recipe C")
        let ranked = RecipeMoodRanker.rank([r1, r2, r3], for: .cozy)
        XCTAssertEqual(ranked.map(\.title), ["Recipe A", "Recipe B", "Recipe C"])
    }

    func testNoMatchBaselineAllScoreZero() {
        let r1 = makeRecipe(title: "Alpha")
        let r2 = makeRecipe(title: "Beta")
        let r3 = makeRecipe(title: "Gamma")
        let ranked = RecipeMoodRanker.rank([r1, r2, r3], for: .fresh)
        XCTAssertEqual(ranked.map(\.title), ["Alpha", "Beta", "Gamma"])
    }

    func testSearchableTextIncludesAllFields() {
        let titleMatch = makeRecipe(title: "Warm Ramen Bowl")
        let taglineMatch = makeRecipe(title: "Neutral", tagline: "A cozy home dish")
        let cuisineMatch = makeRecipe(title: "Neutral 2", cuisine: "Indian")
        let ingredientMatch = makeRecipe(title: "Neutral 3", ingredientNames: ["basil", "lemon"])

        let cozyRanked = RecipeMoodRanker.rank([titleMatch, makeRecipe(title: "No Match 0")], for: .cozy)
        XCTAssertEqual(cozyRanked.first?.title, titleMatch.title, "Title keyword should score")

        let taglineScore = RecipeMoodRanker.rank([taglineMatch, makeRecipe(title: "No Match")], for: .cozy)
        XCTAssertEqual(taglineScore.first?.title, taglineMatch.title, "Tagline keyword should score")

        let boldRanked = RecipeMoodRanker.rank([cuisineMatch, makeRecipe(title: "No Match 2")], for: .bold)
        XCTAssertEqual(boldRanked.first?.title, cuisineMatch.title, "Cuisine keyword should score")

        let freshRanked = RecipeMoodRanker.rank([ingredientMatch, makeRecipe(title: "No Match 3")], for: .fresh)
        XCTAssertEqual(freshRanked.first?.title, ingredientMatch.title, "Ingredient keyword should score")
    }
}
