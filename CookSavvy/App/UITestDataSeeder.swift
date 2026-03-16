//
//  UITestDataSeeder.swift
//  CookSavvy
//

#if DEBUG
import Foundation

@MainActor
struct UITestDataSeeder {
    private static let cookingSessionOffsets = [-1, -2, -4, -6, -8]
    private static let cookingSessionDurations: [TimeInterval] = [1_200, 1_500, 1_800, 2_100, 2_400]
    private static let cookingSessionRatings = [5, 4, 5, 3, 4]

    private let db: DBInterfaceProtocol

    init(db: DBInterfaceProtocol) {
        self.db = db
    }

    func seed(config: UITestConfiguration) {
        do {
            let ingredients = Self.makeIngredients()
            try db.insertIngredients(ingredients)

            let recipes = Self.makeRecipes(ingredients: ingredients)
            try db.insertRecipes(recipes)

            if config.withCookingHistory {
                try seedCookingHistory(recipes: recipes)
            }
            if config.withFavorites {
                try seedFavorites(recipes: recipes)
            }
            if config.withShoppingItems {
                try seedShoppingItems(recipes: recipes)
            }
        } catch {
            assertionFailure("UITestDataSeeder failed: \(error)")
        }
    }

    // MARK: - Ingredients

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
                cleanedIngredients: [byName("Pasta"), byName("Garlic"), byName("Olive Oil"), byName("Parmesan"), byName("Basil")],
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
                cleanedIngredients: [byName("Chicken Breast"), byName("Lemon"), byName("Garlic"), byName("Olive Oil"), byName("Butter")],
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
                cleanedIngredients: [byName("Bell Pepper"), byName("Spinach"), byName("Onion"), byName("Garlic"), byName("Rice")],
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
                cleanedIngredients: [byName("Salmon"), byName("Rice"), byName("Spinach"), byName("Lemon"), byName("Olive Oil")],
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
                cleanedIngredients: [byName("Tofu"), byName("Tomato"), byName("Onion"), byName("Garlic"), byName("Spinach"), byName("Rice")],
                additionalInfo: Recipe.AdditionalInfo(time: "35 min", servings: 4, complexity: "Medium", calories: 310),
                source: .offline,
                tagline: "Hearty plant-based curry.",
                emoji: "🍛"
            ),
        ]
    }

    // MARK: - Cooking History

    private func seedCookingHistory(recipes: [Recipe]) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date())
        let sessionBase = calendar.date(byAdding: .hour, value: 12, to: today) ?? today

        for (index, dayOffset) in Self.cookingSessionOffsets.enumerated() {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: sessionBase) ?? sessionBase
            let recipe = recipes[index % recipes.count]
            if let recipeId = try db.getRecipeId(byTitle: recipe.title) {
                try db.recordCookingSession(
                    recipeId: recipeId,
                    date: date,
                    duration: Self.cookingSessionDurations[index],
                    rating: Self.cookingSessionRatings[index]
                )
            }
        }
    }

    // MARK: - Favorites

    private func seedFavorites(recipes: [Recipe]) throws {
        for recipe in recipes.prefix(2) {
            if let recipeId = try db.getRecipeId(byTitle: recipe.title) {
                try db.addFavorite(recipeId)
            }
        }
    }

    // MARK: - Shopping Items

    private func seedShoppingItems(recipes: [Recipe]) throws {
        guard let firstRecipe = recipes.first else { return }
        _ = try db.addShoppingItems(["Garlic", "Olive Oil", "Parmesan"], recipeTitle: firstRecipe.title)
    }
}
#endif
