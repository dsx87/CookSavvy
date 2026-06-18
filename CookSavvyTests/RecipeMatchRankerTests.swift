import XCTest
@testable import CookSavvy

final class RecipeMatchRankerTests: XCTestCase {

    private func makeRecipe(
        title: String,
        ingredientNames: [String],
        missingIngredients: [String],
        userRating: Double? = nil,
        apiRating: Double? = nil,
        time: String? = nil,
        complexity: String? = nil
    ) -> Recipe {
        let ingredients = ingredientNames.map(Ingredient.init(name:))
        return Recipe(
            title: title,
            ingredients: ingredients,
            instructions: ["Cook"],
            image: "",
            additionalInfo: .init(time: time, servings: nil, complexity: complexity, calories: nil),
            userRating: userRating,
            apiRating: apiRating,
            missingIngredients: missingIngredients
        )
    }

    func testCoverageRatioBeatsMissingCountRatingCookTimeAndComplexity() {
        let betterCoverage = makeRecipe(
            title: "Better Coverage",
            ingredientNames: ["chicken", "rice", "lemon"],
            missingIngredients: [],
            userRating: 2,
            apiRating: 2,
            time: "45 min",
            complexity: "Hard"
        )
        let strongerFallbackSignals = makeRecipe(
            title: "Stronger Fallback Signals",
            ingredientNames: ["chicken", "rice", "lemon", "herbs"],
            missingIngredients: ["herbs"],
            userRating: 5,
            apiRating: 5,
            time: "10 min",
            complexity: "Easy"
        )

        let ranked = RecipeMatchRanker.rank([strongerFallbackSignals, betterCoverage])
        XCTAssertEqual(ranked.first?.title, betterCoverage.title)
    }

    func testMissingCountBreaksTiesWhenCoverageMatches() {
        let fewerMissing = makeRecipe(
            title: "Fewer Missing",
            ingredientNames: ["chicken", "rice"],
            missingIngredients: ["rice"]
        )
        let moreMissing = makeRecipe(
            title: "More Missing",
            ingredientNames: ["chicken", "rice", "lemon", "herbs"],
            missingIngredients: ["rice", "lemon"]
        )

        let ranked = RecipeMatchRanker.rank([moreMissing, fewerMissing])
        XCTAssertEqual(ranked.first?.title, fewerMissing.title)
    }

    func testUserRatingCountsDoubleComparedToAPIRating() {
        let userRated = makeRecipe(
            title: "User Rated",
            ingredientNames: ["chicken", "rice"],
            missingIngredients: [],
            userRating: 3
        )
        let apiRated = makeRecipe(
            title: "API Rated",
            ingredientNames: ["chicken", "rice"],
            missingIngredients: [],
            apiRating: 5
        )

        let ranked = RecipeMatchRanker.rank([apiRated, userRated])
        XCTAssertEqual(ranked.first?.title, userRated.title)
    }

    func testCookTimeAndComplexityBreakRemainingTiesDeterministically() {
        let shorterAndEasier = makeRecipe(
            title: "Alpha",
            ingredientNames: ["chicken", "rice"],
            missingIngredients: [],
            time: "15 min",
            complexity: "Easy"
        )
        let longer = makeRecipe(
            title: "Beta",
            ingredientNames: ["chicken", "rice"],
            missingIngredients: [],
            time: "25 min",
            complexity: "Easy"
        )
        let unknownMetadata = makeRecipe(
            title: "Gamma",
            ingredientNames: ["chicken", "rice"],
            missingIngredients: []
        )

        let ranked = RecipeMatchRanker.rank([unknownMetadata, longer, shorterAndEasier])
        XCTAssertEqual(ranked.map(\.title), ["Alpha", "Beta", "Gamma"])
    }

    // MARK: - Mood Ranking

    func testMoodReordersRecipesWithinSameCoverageTier() {
        // Both recipes: 4 ingredients, 1 missing → coverage 0.75, identical coverage tier + missing count.
        let warmStew = makeRecipe(
            title: "Warm Stew",
            ingredientNames: ["chicken", "rice", "beef", "water"],
            missingIngredients: ["water"]
        )
        let appleBowl = makeRecipe(
            title: "Apple Bowl",
            ingredientNames: ["chicken", "rice", "apple", "water"],
            missingIngredients: ["water"]
        )

        // With a cozy mood, the mood-matching recipe rises within the shared coverage tier...
        let rankedWithMood = RecipeMatchRanker.rank([appleBowl, warmStew], mood: .cozy)
        XCTAssertEqual(rankedWithMood.first?.title, "Warm Stew")

        // ...but with no mood the tie falls through to the alphabetical title tie-break (unchanged behaviour).
        let rankedNoMood = RecipeMatchRanker.rank([warmStew, appleBowl])
        XCTAssertEqual(rankedNoMood.first?.title, "Apple Bowl")
    }

    func testCoverageTierStaysPrimaryEvenWhenMoodIsActive() {
        // Perfect coverage (1.0 → top tier), no cozy signal.
        let perfectMatch = makeRecipe(
            title: "Apple Bowl",
            ingredientNames: ["chicken", "rice"],
            missingIngredients: []
        )
        // Strong cozy signal but only 0.5 coverage (lower tier).
        let cozyButFewerMatches = makeRecipe(
            title: "Warm Stew Soup Ramen",
            ingredientNames: ["chicken", "rice", "beef", "fish", "pork", "lamb"],
            missingIngredients: ["beef", "fish", "pork"]
        )

        let ranked = RecipeMatchRanker.rank([cozyButFewerMatches, perfectMatch], mood: .cozy)
        XCTAssertEqual(ranked.first?.title, "Apple Bowl")
    }
}
