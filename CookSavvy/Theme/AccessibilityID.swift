import Foundation

/// Central registry for deterministic accessibility identifiers used by UI tests and QA automation.
enum AccessibilityID {
    /// Normalizes dynamic fragments into stable token-safe id segments.
    private static func token(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    /// Root tab bar identifiers.
    enum Tab {
        static let discover = "tab.discover"
        static let journey = "tab.journey"
    }

    /// Onboarding flow identifiers.
    enum Onboarding {
        static let skipButton = "onboarding.skipButton"
        static let getStartedButton = "onboarding.getStartedButton"
        static let cameraPage = "onboarding.cameraPage"
        static let typeInsteadButton = "onboarding.typeInsteadButton"

        /// Returns the id for a specific onboarding page index.
        static func page(_ index: Int) -> String {
            "onboarding.page.\(index)"
        }
    }

    /// Discover screen identifiers, including helpers for dynamic content.
    enum Discover {
        static let searchField = "discover.searchField"
        static let findRecipesButton = "discover.findRecipesButton"
        static let cameraButton = "discover.cameraButton"
        static let ingredientGrid = "discover.ingredientGrid"
        static let selectedStrip = "discover.selectedStrip"
        static let alwaysHaveRow = "discover.alwaysHaveRow"
        static let bestMatch = "discover.bestMatch"
        static let moreRecipes = "discover.moreRecipes"
        static let useItAllToggle = "discover.useItAllToggle"
        static let recentSection = "discover.recentSection"
        static let savedSection = "discover.savedSection"
        static let suggestedSection = "discover.suggestedSection"
        static let emptyState = "discover.emptyState"
        static let noResultsState = "discover.noResultsState"

        /// Returns the id for an ingredient chip by name.
        static func ingredient(_ name: String) -> String {
            "discover.ingredient.\(AccessibilityID.token(name))"
        }

        /// Returns the id for an ingredient's pantry-staple toggle.
        static func pantryToggle(_ name: String) -> String {
            "discover.pantryToggle.\(AccessibilityID.token(name))"
        }

        /// Returns the id for an informational Always Have chip by ingredient name.
        static func alwaysHaveChip(_ name: String) -> String {
            "discover.alwaysHave.\(AccessibilityID.token(name))"
        }

        /// Returns the id for an ingredient category control by name.
        static func category(_ name: String) -> String {
            "discover.category.\(AccessibilityID.token(name))"
        }

        /// Returns the id for a mood filter control by name.
        static func mood(_ name: String) -> String {
            "discover.mood.\(AccessibilityID.token(name))"
        }

        /// Returns the id for a cook-time filter control by name.
        static func cookTimeFilter(_ name: String) -> String {
            "discover.filter.time.\(AccessibilityID.token(name))"
        }

        /// Returns the id for a complexity filter control by name.
        static func complexityFilter(_ name: String) -> String {
            "discover.filter.complexity.\(AccessibilityID.token(name))"
        }

        /// Returns the id for a recipe card/row by recipe title.
        static func recipe(_ title: String) -> String {
            "discover.recipe.\(AccessibilityID.token(title))"
        }

        /// Returns the id for a quick badge bound to a recipe title.
        static func badgeQuick(_ title: String) -> String {
            "discover.badge.quick.\(AccessibilityID.token(title))"
        }

        /// Returns the id for an easy badge bound to a recipe title.
        static func badgeEasy(_ title: String) -> String {
            "discover.badge.easy.\(AccessibilityID.token(title))"
        }

        /// Returns the id for a beginner badge bound to a recipe title.
        static func badgeBeginner(_ title: String) -> String {
            "discover.badge.beginner.\(AccessibilityID.token(title))"
        }
    }

    /// Recipe details screen identifiers.
    enum RecipeDetails {
        static let title = "recipeDetails.title"
        static let bookmarkButton = "recipeDetails.bookmarkButton"
        static let startCookingButton = "recipeDetails.startCookingButton"
        static let ingredientsSection = "recipeDetails.ingredientsSection"
        static let stepsSection = "recipeDetails.stepsSection"
        static let addToShoppingList = "recipeDetails.addToShoppingList"
    }

    /// Cook mode identifiers, including dynamic star-rating controls.
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

        /// Returns the id for a specific feedback star index.
        static func star(_ index: Int) -> String {
            "cookMode.star.\(index)"
        }
    }

    /// My Kitchen (Journey) screen identifiers.
    enum Journey {
        static let settingsButton = "journey.settingsButton"
        static let accountCard = "journey.accountCard"
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
        static let monthlyInsights = "journey.monthlyInsights"

        /// Returns the id for a "Cook Again" button tied to a specific session.
        static func cookAgainButton(_ sessionID: Int) -> String {
            "journey.cookAgain.\(sessionID)"
        }

        /// Nested stats identifiers displayed in compact/expanded cards.
        enum Stats {
            static let recipesCooked = "journey.stats.recipesCooked"
            static let ingredientsRescued = "journey.stats.ingredientsRescued"
            static let hoursCooking = "journey.stats.hoursCooking"
            static let monthlyMeals = "journey.stats.monthlyMeals"
            static let monthlyIngredients = "journey.stats.monthlyIngredients"
            static let monthlySavings = "journey.stats.monthlySavings"
        }
    }

    /// Create recipe wizard identifiers.
    enum CreateRecipe {
        static let recipeName = "createRecipe.recipeName"
        static let nextButton = "createRecipe.nextButton"
        static let saveButton = "createRecipe.saveButton"
        static let addIngredient = "createRecipe.addIngredient"
        static let addStep = "createRecipe.addStep"

        /// Returns the id for an ingredient input row by index.
        static func ingredient(_ index: Int) -> String {
            "createRecipe.ingredient.\(index)"
        }

        /// Returns the id for a step input row by index.
        static func step(_ index: Int) -> String {
            "createRecipe.step.\(index)"
        }
    }

    /// Shopping list screen identifiers.
    enum ShoppingList {
        static let emptyState = "shoppingList.emptyState"
        static let clearDone = "shoppingList.clearDone"

        /// Returns the id for a shopping row keyed by ingredient name.
        static func item(_ name: String) -> String {
            "shoppingList.item.\(AccessibilityID.token(name))"
        }

        /// Returns the id for a shopping item checkbox keyed by ingredient name.
        static func checkbox(_ name: String) -> String {
            "shoppingList.checkbox.\(AccessibilityID.token(name))"
        }
    }

    /// Settings screen identifiers.
    enum Settings {
        static let upgradeButton = "settings.upgradeButton"
        static let clearRecent = "settings.clearRecent"
        static let subscriptionSection = "settings.subscriptionSection"
        static let versionLabel = "settings.versionLabel"
    }

    /// Upgrade screen identifiers.
    enum Upgrade {
        static let subscribeButton = "upgrade.subscribeButton"
        static let monthlySubscribeButton = "upgrade.monthlySubscribeButton"
        static let premiumPlan = "upgrade.premiumPlan"
        static let monthlyPlan = "upgrade.monthlyPlan"
    }

    /// Camera screen identifiers.
    enum Camera {
        static let scanLimitBadge = "camera.scanLimitBadge"
    }
}
