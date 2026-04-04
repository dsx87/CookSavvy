import Foundation

enum AccessibilityID {
    private static func token(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    enum Tab {
        static let discover = "tab.discover"
        static let journey = "tab.journey"
    }

    enum Onboarding {
        static let skipButton = "onboarding.skipButton"
        static let getStartedButton = "onboarding.getStartedButton"

        static func page(_ index: Int) -> String {
            "onboarding.page.\(index)"
        }
    }

    enum Discover {
        static let searchField = "discover.searchField"
        static let findRecipesButton = "discover.findRecipesButton"
        static let cameraButton = "discover.cameraButton"
        static let ingredientGrid = "discover.ingredientGrid"
        static let selectedStrip = "discover.selectedStrip"
        static let bestMatch = "discover.bestMatch"
        static let moreRecipes = "discover.moreRecipes"
        static let useItAllToggle = "discover.useItAllToggle"
        static let recentSection = "discover.recentSection"
        static let savedSection = "discover.savedSection"
        static let suggestedSection = "discover.suggestedSection"
        static let emptyState = "discover.emptyState"
        static let noResultsState = "discover.noResultsState"

        static func ingredient(_ name: String) -> String {
            "discover.ingredient.\(AccessibilityID.token(name))"
        }

        static func category(_ name: String) -> String {
            "discover.category.\(AccessibilityID.token(name))"
        }

        static func mood(_ name: String) -> String {
            "discover.mood.\(AccessibilityID.token(name))"
        }

        static func recipe(_ title: String) -> String {
            "discover.recipe.\(AccessibilityID.token(title))"
        }

        static func badgeQuick(_ title: String) -> String {
            "discover.badge.quick.\(AccessibilityID.token(title))"
        }

        static func badgeEasy(_ title: String) -> String {
            "discover.badge.easy.\(AccessibilityID.token(title))"
        }

        static func badgeBeginner(_ title: String) -> String {
            "discover.badge.beginner.\(AccessibilityID.token(title))"
        }
    }

    enum RecipeDetails {
        static let title = "recipeDetails.title"
        static let bookmarkButton = "recipeDetails.bookmarkButton"
        static let startCookingButton = "recipeDetails.startCookingButton"
        static let ingredientsSection = "recipeDetails.ingredientsSection"
        static let stepsSection = "recipeDetails.stepsSection"
        static let addToShoppingList = "recipeDetails.addToShoppingList"
    }

    enum CookMode {
        static let closeButton = "cookMode.closeButton"
        static let previousButton = "cookMode.previousButton"
        static let nextButton = "cookMode.nextButton"
        static let doneButton = "cookMode.doneButton"
        static let stepText = "cookMode.stepText"
        static let stepProgress = "cookMode.stepProgress"
        static let feedbackOverlay = "cookMode.feedbackOverlay"
        static let skipRating = "cookMode.skipRating"
        static let submitButton = "cookMode.submitButton"

        static func star(_ index: Int) -> String {
            "cookMode.star.\(index)"
        }
    }

    enum Journey {
        static let settingsButton = "journey.settingsButton"
        static let savedRecipes = "journey.savedRecipes"
        static let shoppingListShortcut = "journey.shoppingListShortcut"
        static let myRecipes = "journey.myRecipes"
        static let createRecipeCard = "journey.createRecipeCard"
        static let weeklyActivity = "journey.weeklyActivity"
        static let achievements = "journey.achievements"
        static let achievementsCompact = "journey.achievementsCompact"
        static let achievementsExpanded = "journey.achievementsExpanded"
        static let achievementsToggle = "journey.achievementsToggle"
        static let achievementsAntiWaste = "journey.achievementsAntiWaste"
        static let recentActivity = "journey.recentActivity"
        static let monthlyStats = "journey.monthlyStats"

        static func cookAgainButton(_ sessionID: Int) -> String {
            "journey.cookAgain.\(sessionID)"
        }

        enum Stats {
            static let recipesCooked = "journey.stats.recipesCooked"
            static let ingredientsRescued = "journey.stats.ingredientsRescued"
            static let hoursCooking = "journey.stats.hoursCooking"
            static let monthlyMeals = "journey.stats.monthlyMeals"
            static let monthlyIngredients = "journey.stats.monthlyIngredients"
        }
    }

    enum CreateRecipe {
        static let recipeName = "createRecipe.recipeName"
        static let nextButton = "createRecipe.nextButton"
        static let saveButton = "createRecipe.saveButton"
        static let addIngredient = "createRecipe.addIngredient"
        static let addStep = "createRecipe.addStep"

        static func ingredient(_ index: Int) -> String {
            "createRecipe.ingredient.\(index)"
        }

        static func step(_ index: Int) -> String {
            "createRecipe.step.\(index)"
        }
    }

    enum ShoppingList {
        static let emptyState = "shoppingList.emptyState"
        static let clearDone = "shoppingList.clearDone"

        static func item(_ name: String) -> String {
            "shoppingList.item.\(AccessibilityID.token(name))"
        }

        static func checkbox(_ name: String) -> String {
            "shoppingList.checkbox.\(AccessibilityID.token(name))"
        }
    }

    enum Settings {
        static let upgradeButton = "settings.upgradeButton"
        static let clearRecent = "settings.clearRecent"
        static let subscriptionSection = "settings.subscriptionSection"
        static let versionLabel = "settings.versionLabel"
    }

    enum Upgrade {
        static let subscribeButton = "upgrade.subscribeButton"
        static let premiumPlan = "upgrade.premiumPlan"
    }

    enum Camera {
        static let scanLimitBadge = "camera.scanLimitBadge"
    }
}
