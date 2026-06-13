//
//  UITestDataSeeder.swift
//  CookSavvy
//

#if DEBUG
import Foundation

/// Seeds deterministic data into the database before UI tests run.
///
/// Called from `AppContainer.configureForUITesting(_:)` after the in-memory database is
/// created. All seeded data uses fixed, predictable values so that UI assertions can rely on
/// specific recipe titles, ingredient names, and session dates.
@MainActor
struct UITestDataSeeder {
    /// Day offsets from today used to distribute cooking sessions across the past week.
    private static let cookingSessionOffsets = [-1, -2, -4, -6, -8]
    /// Duration in seconds for each seeded cooking session, matched by index to `cookingSessionOffsets`.
    private static let cookingSessionDurations: [TimeInterval] = [1_200, 1_500, 1_800, 2_100, 2_400]
    /// Star ratings for each seeded cooking session, matched by index.
    private static let cookingSessionRatings = [5, 4, 5, 3, 4]

    private let db: DBInterfaceProtocol

    /// - Parameter db: The database interface to write seeded data into.
    init(db: DBInterfaceProtocol) {
        self.db = db
    }

    /// Runs the full seeding pass for the given configuration.
    ///
    /// Always inserts the base ingredient and recipe sets unless `config.isEmptyDatabase` is true.
    /// Optionally extends the dataset and seeds cooking history, favorites, and shopping items
    /// based on the flags in `config`.
    ///
    /// - Parameter config: The launch-argument configuration that controls what is seeded.
    func seed(config: UITestConfiguration) async {
        guard !config.isEmptyDatabase else { return }

        do {
            let ingredients = Self.makeIngredients()
            try await db.insertIngredients(ingredients)

            var recipes = Self.makeRecipes(ingredients: ingredients)
            if config.withLargeDataset {
                recipes.append(contentsOf: Self.makeLargeDatasetRecipes(ingredients: ingredients))
            }
            try await db.insertRecipes(recipes)

            if config.withCookingHistory {
                try await seedCookingHistory(recipes: recipes)
            }
            if config.withFavorites {
                try await seedFavorites(recipes: recipes)
            }
            if config.withShoppingItems {
                try await seedShoppingItems(recipes: recipes)
            }
        } catch {
            assertionFailure("UITestDataSeeder failed: \(error)")
        }
    }

    // MARK: - Ingredients

    /// Returns the deterministic set of 15 ingredients used across all seeded recipes.
    private static func makeIngredients() -> [Ingredient] {
        [
            Ingredient(name: "Garlic",         description: nil, pictureFileName: nil, foodGroup: "Vegetables",     foodSubgroup: "Alliums"),
            Ingredient(name: "Onion",          description: nil, pictureFileName: nil, foodGroup: "Vegetables",     foodSubgroup: "Alliums"),
            Ingredient(name: "Chicken Breast", description: nil, pictureFileName: nil, foodGroup: "Protein",        foodSubgroup: "Poultry"),
            Ingredient(name: "Salmon",         description: nil, pictureFileName: nil, foodGroup: "Protein",        foodSubgroup: "Fish"),
            Ingredient(name: "Tofu",           description: nil, pictureFileName: nil, foodGroup: "Protein",        foodSubgroup: "Soy"),
            Ingredient(name: "Bell Pepper",    description: nil, pictureFileName: nil, foodGroup: "Vegetables",     foodSubgroup: "Peppers"),
            Ingredient(name: "Spinach",        description: nil, pictureFileName: nil, foodGroup: "Vegetables",     foodSubgroup: "Leafy Greens"),
            Ingredient(name: "Tomato",         description: nil, pictureFileName: nil, foodGroup: "Vegetables",     foodSubgroup: "Fruit Vegetables"),
            Ingredient(name: "Pasta",          description: nil, pictureFileName: nil, foodGroup: "Grains",         foodSubgroup: "Wheat"),
            Ingredient(name: "Rice",           description: nil, pictureFileName: nil, foodGroup: "Grains",         foodSubgroup: "Cereal Grains"),
            Ingredient(name: "Lemon",          description: nil, pictureFileName: nil, foodGroup: "Fruits",         foodSubgroup: "Citrus"),
            Ingredient(name: "Basil",          description: nil, pictureFileName: nil, foodGroup: "Herbs & Spices", foodSubgroup: "Herbs"),
            Ingredient(name: "Parmesan",       description: nil, pictureFileName: nil, foodGroup: "Dairy",          foodSubgroup: "Cheese"),
            Ingredient(name: "Butter",         description: nil, pictureFileName: nil, foodGroup: "Dairy",          foodSubgroup: "Butter"),
            Ingredient(name: "Olive Oil",      description: nil, pictureFileName: nil, foodGroup: "Herbs & Spices", foodSubgroup: "Oils"),
        ]
    }

    // MARK: - Recipes

    /// Builds the base set of 5 seeded recipes, each composed from the provided ingredients.
    ///
    /// - Parameter ingredients: The ingredient pool returned by ``makeIngredients()``.
    private static func makeRecipes(ingredients: [Ingredient]) -> [Recipe] {
        let byName: (String) -> Ingredient = { name in
            ingredients.first(where: { $0.name == name }) ?? Ingredient(name: name)
        }

        return [
            Recipe(
                title: "Test Garlic Pasta",
                ingredients: [byName("Pasta"), byName("Garlic"), byName("Olive Oil"), byName("Parmesan"), byName("Basil")],
                instructions: [
                    Recipe.Step(text: "Boil pasta in salted water until al dente.", timerMinutes: 10),
                    Recipe.Step(text: "Sauté minced garlic in olive oil over medium heat."),
                    Recipe.Step(text: "Toss drained pasta with garlic oil and parmesan."),
                    Recipe.Step(text: "Garnish with fresh basil and serve."),
                ],
                image: "recipe_placeholder",
                additionalInfo: Recipe.AdditionalInfo(time: "20 min", servings: 2, complexity: "Easy", calories: 480),
                source: .offline,
                tagline: "Classic Italian comfort food.",
                emoji: "🍝"
            ),
            Recipe(
                title: "Test Lemon Chicken",
                ingredients: [byName("Chicken Breast"), byName("Lemon"), byName("Garlic"), byName("Olive Oil"), byName("Butter")],
                instructions: [
                    Recipe.Step(text: "Season chicken breast with salt and pepper."),
                    Recipe.Step(text: "Sear in olive oil until golden on both sides.", timerMinutes: 8),
                    Recipe.Step(text: "Add garlic, butter and lemon juice to the pan."),
                    Recipe.Step(text: "Simmer until chicken is cooked through.", timerMinutes: 6),
                    Recipe.Step(text: "Rest for two minutes before slicing."),
                ],
                image: "recipe_placeholder",
                additionalInfo: Recipe.AdditionalInfo(time: "25 min", servings: 2, complexity: "Easy", calories: 360),
                source: .offline,
                tagline: "Bright and juicy pan-seared chicken.",
                emoji: "🍋"
            ),
            Recipe(
                title: "Test Veggie Stir-Fry",
                ingredients: [byName("Bell Pepper"), byName("Spinach"), byName("Onion"), byName("Garlic"), byName("Rice")],
                instructions: [
                    Recipe.Step(text: "Cook rice according to package instructions.", timerMinutes: 15),
                    Recipe.Step(text: "Heat oil in a wok or large skillet over high heat."),
                    Recipe.Step(text: "Stir-fry onion and garlic for two minutes."),
                    Recipe.Step(text: "Add bell pepper and spinach, cook until tender-crisp.", timerMinutes: 4),
                    Recipe.Step(text: "Season and serve over rice."),
                ],
                image: "recipe_placeholder",
                additionalInfo: Recipe.AdditionalInfo(time: "30 min", servings: 3, complexity: "Easy", calories: 290),
                source: .offline,
                tagline: "Quick and colourful weeknight veggie bowl.",
                emoji: "🥦"
            ),
            Recipe(
                title: "Test Salmon Bowl",
                ingredients: [byName("Salmon"), byName("Rice"), byName("Spinach"), byName("Lemon"), byName("Olive Oil")],
                instructions: [
                    Recipe.Step(text: "Cook rice and set aside.", timerMinutes: 15),
                    Recipe.Step(text: "Season salmon fillet with salt, pepper and lemon zest."),
                    Recipe.Step(text: "Pan-fry salmon skin-side down for four minutes.", timerMinutes: 4),
                    Recipe.Step(text: "Flip and cook for a further two minutes.", timerMinutes: 2),
                    Recipe.Step(text: "Assemble bowl with rice, spinach and salmon. Drizzle with lemon."),
                ],
                image: "recipe_placeholder",
                additionalInfo: Recipe.AdditionalInfo(time: "25 min", servings: 2, complexity: "Medium", calories: 520),
                source: .offline,
                tagline: "Healthy omega-3 packed bowl.",
                emoji: "🐟"
            ),
            Recipe(
                title: "Test Tofu Curry",
                ingredients: [byName("Tofu"), byName("Tomato"), byName("Onion"), byName("Garlic"), byName("Spinach"), byName("Rice")],
                instructions: [
                    Recipe.Step(text: "Press and cube tofu, then pan-fry until golden.", timerMinutes: 8),
                    Recipe.Step(text: "Sauté onion and garlic until translucent."),
                    Recipe.Step(text: "Add diced tomato and simmer for five minutes.", timerMinutes: 5),
                    Recipe.Step(text: "Stir in tofu and spinach, cook until wilted.", timerMinutes: 3),
                    Recipe.Step(text: "Serve over steamed rice."),
                ],
                image: "recipe_placeholder",
                additionalInfo: Recipe.AdditionalInfo(time: "35 min", servings: 4, complexity: "Medium", calories: 310),
                source: .offline,
                tagline: "Hearty plant-based curry.",
                emoji: "🍛"
            ),
        ]
    }

    /// Generates 125 additional recipes (5 blueprints × 25 iterations) for large-dataset tests.
    ///
    /// Titles are suffixed with the iteration index to guarantee uniqueness. Serving count and
    /// calorie values vary slightly across iterations to add realistic diversity without
    /// sacrificing determinism.
    ///
    /// - Parameter ingredients: The ingredient pool returned by ``makeIngredients()``.
    private static func makeLargeDatasetRecipes(ingredients: [Ingredient]) -> [Recipe] {
        let byName: (String) -> Ingredient = { name in
            ingredients.first(where: { $0.name == name }) ?? Ingredient(name: name)
        }

        let recipeBlueprints: [(String, [String], [Recipe.Step], String, String, String)] = [
            ("Large Test Garlic Skillet", ["Garlic", "Onion", "Bell Pepper", "Rice"], [
                Recipe.Step(text: "Toast the rice in a skillet for two minutes."),
                Recipe.Step(text: "Add onion, garlic and bell pepper, then cook until fragrant.", timerMinutes: 6),
                Recipe.Step(text: "Stir in water and simmer until tender.", timerMinutes: 14),
            ], "28 min", "Easy", "Quick skillet rice with garlic."),
            ("Large Test Protein Bowl", ["Chicken Breast", "Rice", "Spinach", "Lemon"], [
                Recipe.Step(text: "Cook the rice until fluffy.", timerMinutes: 15),
                Recipe.Step(text: "Pan-sear the chicken until cooked through.", timerMinutes: 10),
                Recipe.Step(text: "Assemble with spinach and lemon."),
            ], "30 min", "Easy", "Balanced protein bowl."),
            ("Large Test Garden Pasta", ["Pasta", "Tomato", "Basil", "Garlic"], [
                Recipe.Step(text: "Boil the pasta until tender.", timerMinutes: 10),
                Recipe.Step(text: "Cook tomato and garlic into a quick sauce.", timerMinutes: 8),
                Recipe.Step(text: "Toss with pasta and basil."),
            ], "24 min", "Easy", "Bright garden pasta."),
            ("Large Test Salmon Plate", ["Salmon", "Rice", "Lemon", "Spinach"], [
                Recipe.Step(text: "Cook rice and keep warm.", timerMinutes: 15),
                Recipe.Step(text: "Roast salmon until just flaky.", timerMinutes: 12),
                Recipe.Step(text: "Serve over spinach with lemon."),
            ], "32 min", "Medium", "Roasted salmon with rice."),
            ("Large Test Curry Pot", ["Tofu", "Tomato", "Onion", "Garlic", "Rice"], [
                Recipe.Step(text: "Brown the tofu on all sides.", timerMinutes: 8),
                Recipe.Step(text: "Cook onion, garlic and tomato into a sauce.", timerMinutes: 10),
                Recipe.Step(text: "Simmer with tofu and serve over rice.", timerMinutes: 12),
            ], "35 min", "Medium", "Warm curry pot."),
        ]

        return (1...25).flatMap { index in
            recipeBlueprints.enumerated().map { blueprintIndex, blueprint in
                let (baseTitle, ingredientNames, steps, time, complexity, tagline) = blueprint
                let title = "\(baseTitle) \(index)-\(blueprintIndex + 1)"
                let recipeIngredients = ingredientNames.map(byName)
                return Recipe(
                    title: title,
                    ingredients: recipeIngredients,
                    instructions: steps,
                    image: "recipe_placeholder",
                    additionalInfo: Recipe.AdditionalInfo(
                        time: time,
                        servings: 2 + (index % 3),
                        complexity: complexity,
                        calories: 320 + (index * 7)
                    ),
                    source: .offline,
                    tagline: tagline,
                    emoji: blueprintIndex.isMultiple(of: 2) ? "🍲" : "🥗"
                )
            }
        }
    }

    // MARK: - Cooking History

    /// Inserts 5 cooking sessions spread across the past 8 days using fixed offsets and ratings.
    ///
    /// - Parameter recipes: The full recipe set to pull session subjects from (cycled by index).
    /// - Throws: Database write errors.
    private func seedCookingHistory(recipes: [Recipe]) async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date())
        let sessionBase = calendar.date(byAdding: .hour, value: 12, to: today) ?? today

        for (index, dayOffset) in Self.cookingSessionOffsets.enumerated() {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: sessionBase) ?? sessionBase
            let recipe = recipes[index % recipes.count]
            if let recipeId = try await db.getRecipeId(byTitle: recipe.title) {
                try await db.recordCookingSession(
                    recipeId: recipeId,
                    date: date,
                    duration: Self.cookingSessionDurations[index],
                    rating: Self.cookingSessionRatings[index]
                )
            }
        }
    }

    // MARK: - Favorites

    /// Marks the first two seeded recipes as favorites.
    ///
    /// - Parameter recipes: The full recipe set.
    /// - Throws: Database write errors.
    private func seedFavorites(recipes: [Recipe]) async throws {
        for recipe in recipes.prefix(2) {
            if let recipeId = try await db.getRecipeId(byTitle: recipe.title) {
                try await db.addFavorite(recipeId)
            }
        }
    }

    // MARK: - Shopping Items

    /// Adds three shopping items (Garlic, Olive Oil, Parmesan) attributed to the first seeded recipe.
    ///
    /// - Parameter recipes: The full recipe set; uses the first recipe for title attribution.
    /// - Throws: Database write errors.
    private func seedShoppingItems(recipes: [Recipe]) async throws {
        guard let firstRecipe = recipes.first else { return }
        _ = try await db.addShoppingItems(["Garlic", "Olive Oil", "Parmesan"], recipeTitle: firstRecipe.title)
    }
}
#endif
