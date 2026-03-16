import Foundation

enum Strings {

    enum Common {
        static let ok = String(localized: "common.ok", defaultValue: "OK")
        static let cancel = String(localized: "common.cancel", defaultValue: "Cancel")
        static let minutesShort = String(localized: "common.minutesShort", defaultValue: "%lld min")
        static let minutesCompact = String(localized: "common.minutesCompact", defaultValue: "%lldm")
    }

    enum Tab {
        static let discover = String(localized: "tab.discover", defaultValue: "Discover")
        static let journey = String(localized: "tab.journey", defaultValue: "Journey")
    }

    enum RecipeDetails {
        static let ingredientsTitle = String(localized: "recipeDetails.ingredientsTitle", defaultValue: "🛒 Ingredients")
        static let instructionsTitle = String(localized: "recipeDetails.instructionsTitle", defaultValue: "🧑‍🍳 Instructions")
        static let youHave = String(localized: "recipeDetails.youHave", defaultValue: "You have this")
        static let youNeed = String(localized: "recipeDetails.youNeed", defaultValue: "You need this")
        static let byAuthor = String(localized: "recipeDetails.byAuthor", defaultValue: "by %@")
        static let sectionIngredients = String(localized: "recipeDetails.sectionIngredients", defaultValue: "INGREDIENTS")
        static let sectionSteps = String(localized: "recipeDetails.sectionSteps", defaultValue: "STEPS")
    }

    enum Settings {
        static let navigationTitle = String(localized: "settings.navigationTitle", defaultValue: "Settings")
        static let appearanceHeader = String(localized: "settings.appearanceHeader", defaultValue: "Appearance")
        static let appearanceFooter = String(localized: "settings.appearanceFooter", defaultValue: "Choose Light, Dark, or follow your device settings.")
        static let appearancePickerLabel = String(localized: "settings.appearancePickerLabel", defaultValue: "Theme")
        static let appearanceLight = String(localized: "settings.appearanceLight", defaultValue: "Light")
        static let appearanceDark = String(localized: "settings.appearanceDark", defaultValue: "Dark")
        static let appearanceSystem = String(localized: "settings.appearanceSystem", defaultValue: "Use System Settings")
        static let subscriptionHeader = String(localized: "settings.subscriptionHeader", defaultValue: "Subscription Plan")
        static let upgradePlan = String(localized: "settings.upgradePlan", defaultValue: "Upgrade Plan")
        static let restorePurchases = String(localized: "settings.restorePurchases", defaultValue: "Restore Purchases")
        static let manageSubscription = String(localized: "settings.manageSubscription", defaultValue: "Manage Subscription")
        static let recipeSourcesHeader = String(localized: "settings.recipeSourcesHeader", defaultValue: "Recipe Sources")
        static let recipeSourcesFooter = String(localized: "settings.recipeSourcesFooter", defaultValue: "Select which sources to use when searching for recipes. At least one source must be enabled.")
        static let localRecipes = String(localized: "settings.localRecipes", defaultValue: "Local Recipes")
        static let offlineDatabase = String(localized: "settings.offlineDatabase", defaultValue: "Offline database")
        static let onlineRecipes = String(localized: "settings.onlineRecipes", defaultValue: "Online Recipes")
        static let apiSource = String(localized: "settings.apiSource", defaultValue: "API source")
        static let aiRecipes = String(localized: "settings.aiRecipes", defaultValue: "AI Recipes")
        static let aiGeneratedRecipes = String(localized: "settings.aiGeneratedRecipes", defaultValue: "AI-generated recipes")
        static let extendedRecipes = String(localized: "settings.extendedRecipes", defaultValue: "Extended Recipes")
        static let extendedRecipesDescription = String(localized: "settings.extendedRecipesDescription", defaultValue: "Search online databases for more options")
        static let statisticsHeader = String(localized: "settings.statisticsHeader", defaultValue: "Statistics")
        static let totalRecipes = String(localized: "settings.totalRecipes", defaultValue: "Total Recipes")
        static let favoriteRecipes = String(localized: "settings.favoriteRecipes", defaultValue: "Favorite Recipes")
        static let recentRecipes = String(localized: "settings.recentRecipes", defaultValue: "Recent Recipes")
        static let dataManagementHeader = String(localized: "settings.dataManagementHeader", defaultValue: "Data Management")
        static let clearRecentButton = String(localized: "settings.clearRecentButton", defaultValue: "Clear Recent Data")
        static let clearFavoritesButton = String(localized: "settings.clearFavoritesButton", defaultValue: "Clear Favorites")
        static let dataManagementFooter = String(localized: "settings.dataManagementFooter", defaultValue: "Clearing data cannot be undone")
        static let appInfoHeader = String(localized: "settings.appInfoHeader", defaultValue: "App Information")
        static let versionLabel = String(localized: "settings.versionLabel", defaultValue: "Version")
        static let buildLabel = String(localized: "settings.buildLabel", defaultValue: "Build")
        static let clearRecentAlertTitle = String(localized: "settings.clearRecentAlertTitle", defaultValue: "Clear Recent Data?")
        static let clearFavoritesAlertTitle = String(localized: "settings.clearFavoritesAlertTitle", defaultValue: "Clear Favorites?")
        static let alertClear = String(localized: "settings.alertClear", defaultValue: "Clear")
        static let clearRecentAlertMessage = String(localized: "settings.clearRecentAlertMessage", defaultValue: "This will clear all recent ingredients, recipes, and searches. This action cannot be undone.")
        static let clearFavoritesAlertMessage = String(localized: "settings.clearFavoritesAlertMessage", defaultValue: "This will remove all favorited recipes. This action cannot be undone.")
        static let restoreFailed = String(localized: "settings.restoreFailed", defaultValue: "Restore Failed")
    }

    enum Camera {
        static let accessRequired = String(localized: "camera.accessRequired", defaultValue: "Camera Access Required")
        static let accessDescription = String(localized: "camera.accessDescription", defaultValue: "Please allow camera access in Settings to scan ingredients")
        static let openSettings = String(localized: "camera.openSettings", defaultValue: "Open Settings")
        static let detecting = String(localized: "camera.detecting", defaultValue: "Detecting ingredients...")
        static let noIngredientsTitle = String(localized: "camera.noIngredientsTitle", defaultValue: "No Ingredients Found")
        static let noIngredientsSubtitle = String(localized: "camera.noIngredientsSubtitle", defaultValue: "Try taking another photo with ingredients clearly visible")
        static let tryAgain = String(localized: "camera.tryAgain", defaultValue: "Try Again")
    }

    enum Upgrade {
        static let navigationTitle = String(localized: "upgrade.navigationTitle", defaultValue: "Upgrade")
        static let done = String(localized: "upgrade.done", defaultValue: "Done")
        static let autoRenew = String(localized: "upgrade.autoRenew", defaultValue: "Subscriptions auto-renew monthly until cancelled.")
        static let unlockTitle = String(localized: "upgrade.unlockTitle", defaultValue: "Upgrade to CookSavvy+")
        static let unlockSubtitle = String(localized: "upgrade.unlockSubtitle", defaultValue: "Faster dinner decisions with more recipes and camera scanning")
        static let current = String(localized: "upgrade.current", defaultValue: "Current")
        static let subscribe = String(localized: "upgrade.subscribe", defaultValue: "Subscribe")
        static let purchaseFailed = String(localized: "upgrade.purchaseFailed", defaultValue: "Purchase Failed")
        static let unknownError = String(localized: "upgrade.unknownError", defaultValue: "An unknown error occurred")
    }

    enum Discover {
        static let greetingMorning = String(localized: "discover.greetingMorning", defaultValue: "What needs using up? ☀️")
        static let greetingAfternoon = String(localized: "discover.greetingAfternoon", defaultValue: "Let's use what you've got 🌤️")
        static let greetingEvening = String(localized: "discover.greetingEvening", defaultValue: "Dinner from what's on hand 🍽️")
        static let greetingLateNight = String(localized: "discover.greetingLateNight", defaultValue: "Late night fridge rescue 🌜")
        static let kitchenTitle = String(localized: "discover.kitchenTitle", defaultValue: "What's for dinner?")
        static let kitchenSubtitle = String(localized: "discover.kitchenSubtitle", defaultValue: "Add what you have — we'll find recipes to use it all")
        static let recipesForYou = String(localized: "discover.recipesForYou", defaultValue: "Your dinner options")
        static let yourIngredients = String(localized: "discover.yourIngredients", defaultValue: "YOUR INGREDIENTS")
        static let edit = String(localized: "discover.edit", defaultValue: "Edit")
        static let seeAll = String(localized: "discover.seeAll", defaultValue: "See All")
        static let bestMatch = String(localized: "discover.bestMatch", defaultValue: "TOP PICK")
        static let moreRecipes = String(localized: "discover.moreRecipes", defaultValue: "MORE OPTIONS")
        static let recentSection = String(localized: "discover.recentSection", defaultValue: "RECENT")
        static let savedSection = String(localized: "discover.savedSection", defaultValue: "SAVED")
        static let addYourOwn = String(localized: "discover.addYourOwn", defaultValue: "Add Your Own")
        static let allIngredients = String(localized: "discover.allIngredients", defaultValue: "ALL INGREDIENTS")
        static let searchPlaceholder = String(localized: "discover.searchPlaceholder", defaultValue: "Search ingredients...")
        static let findRecipes = String(localized: "discover.findRecipes", defaultValue: "Find Dinner")
        static let scansRemaining = String(localized: "discover.scansRemaining", defaultValue: "%lld scans left")
        static let scansExhausted = String(localized: "discover.scansExhausted", defaultValue: "No scans left")
        static let matchLabel = String(localized: "discover.matchLabel", defaultValue: "Uses %lld of %lld ingredients")
        static let matchLabelAll = String(localized: "discover.matchLabelAll", defaultValue: "You have all the ingredients!")
        static let matchDetailsTitle = String(localized: "discover.matchDetailsTitle", defaultValue: "Matching ingredients")
        static let matchDetailsEmpty = String(localized: "discover.matchDetailsEmpty", defaultValue: "No exact ingredient matches found.")
        static let missingCount = String(localized: "discover.missingCount", defaultValue: "Missing %lld")
        static let haveAll = String(localized: "discover.haveAll", defaultValue: "You have everything!")
        static let useItAll = String(localized: "discover.useItAll", defaultValue: "Use It All")
        static let suggestedForYou = String(localized: "discover.suggestedForYou", defaultValue: "SUGGESTED FOR YOU")
        static let suggestedBecause = String(localized: "discover.suggestedBecause", defaultValue: "Based on your %@ recipes")
        static let resultsFound = String(localized: "discover.resultsFound", defaultValue: "%lld found")
        static let searchErrorMessage = String(localized: "discover.searchErrorMessage", defaultValue: "Some recipe sources couldn't be reached — showing available results")
        static let searchFailedMessage = String(localized: "discover.searchFailedMessage", defaultValue: "Search failed — please try again")
        static let quickMealSuffix = String(localized: "discover.quickMealSuffix", defaultValue: " · Quick %lld-min meal")
        static let retry = String(localized: "discover.retry", defaultValue: "Retry")
    }

    enum Journey {
        static let navigationTitle = String(localized: "journey.navigationTitle", defaultValue: "Journey")
        static let homeChef = String(localized: "journey.homeChef", defaultValue: "Home Chef")
        static let recipesCooked = String(localized: "journey.recipesCooked", defaultValue: "Recipes\nCooked")
        static let dayStreak = String(localized: "journey.dayStreak", defaultValue: "Day\nStreak")
        static let hoursCooking = String(localized: "journey.hoursCooking", defaultValue: "Hours\nCooking")
        static let myRecipes = String(localized: "journey.myRecipes", defaultValue: "MY RECIPES")
        static let addRecipe = String(localized: "journey.addRecipe", defaultValue: "Add Recipe")
        static let thisWeek = String(localized: "journey.thisWeek", defaultValue: "THIS WEEK")
        static let achievements = String(localized: "journey.achievements", defaultValue: "ACHIEVEMENTS")
        static let milestones = String(localized: "journey.milestones", defaultValue: "MILESTONES")
        static let milestonesEarned = String(localized: "journey.milestonesEarned", defaultValue: "%lld of %lld earned")
        static let recentActivity = String(localized: "journey.recentActivity", defaultValue: "RECENT ACTIVITY")
        static let seeAll = String(localized: "journey.seeAll", defaultValue: "See All")
        static let shareCreations = String(localized: "journey.shareCreations", defaultValue: "Share your own creations")
    }

    enum CookMode {
        static let stepOf = String(localized: "cookMode.stepOf", defaultValue: "Step %lld of %lld")
        static let startTimer = String(localized: "cookMode.startTimer", defaultValue: "Start Timer")
        static let pause = String(localized: "cookMode.pause", defaultValue: "Pause")
        static let done = String(localized: "cookMode.done", defaultValue: "Done")
        static let finish = String(localized: "cookMode.finish", defaultValue: "Finish")
        static let startCooking = String(localized: "cookMode.startCooking", defaultValue: "Let's Cook")
        static let howWasIt = String(localized: "cookMode.howWasIt", defaultValue: "How was it?")
        static let submit = String(localized: "cookMode.submit", defaultValue: "Submit")
        static let skipRating = String(localized: "cookMode.skipRating", defaultValue: "Skip")
    }

    enum CreateRecipe {
        static let nameYourRecipe = String(localized: "createRecipe.nameYourRecipe", defaultValue: "Name Your Recipe")
        static let addIngredients = String(localized: "createRecipe.addIngredients", defaultValue: "Add Ingredients")
        static let addSteps = String(localized: "createRecipe.addSteps", defaultValue: "Add Steps")
        static let details = String(localized: "createRecipe.details", defaultValue: "Details")
        static let reviewAndSave = String(localized: "createRecipe.reviewAndSave", defaultValue: "Review & Save")
        static let recipeName = String(localized: "createRecipe.recipeName", defaultValue: "Recipe name")
        static let taglinePlaceholder = String(localized: "createRecipe.taglinePlaceholder", defaultValue: "Short description — e.g. 'Creamy comfort in a bowl'")
        static let next = String(localized: "createRecipe.next", defaultValue: "Next")
        static let back = String(localized: "createRecipe.back", defaultValue: "Back")
        static let saveRecipe = String(localized: "createRecipe.saveRecipe", defaultValue: "Save Recipe")
        static let sectionRecipeName = String(localized: "createRecipe.sectionRecipeName", defaultValue: "RECIPE NAME")
        static let sectionTagline = String(localized: "createRecipe.sectionTagline", defaultValue: "TAGLINE")
        static let sectionChooseIcon = String(localized: "createRecipe.sectionChooseIcon", defaultValue: "CHOOSE AN ICON")
        static let sectionIngredients = String(localized: "createRecipe.sectionIngredients", defaultValue: "INGREDIENTS")
        static let ingredientPlaceholder = String(localized: "createRecipe.ingredientPlaceholder", defaultValue: "Ingredient %lld")
        static let addIngredient = String(localized: "createRecipe.addIngredient", defaultValue: "Add Ingredient")
        static let sectionSteps = String(localized: "createRecipe.sectionSteps", defaultValue: "COOKING STEPS")
        static let stepPlaceholder = String(localized: "createRecipe.stepPlaceholder", defaultValue: "Step %lld")
        static let addStep = String(localized: "createRecipe.addStep", defaultValue: "Add Step")
        static let sectionCookTime = String(localized: "createRecipe.sectionCookTime", defaultValue: "COOK TIME")
        static let sectionServings = String(localized: "createRecipe.sectionServings", defaultValue: "SERVINGS")
        static let sectionDifficulty = String(localized: "createRecipe.sectionDifficulty", defaultValue: "DIFFICULTY")
        static let untitledRecipe = String(localized: "createRecipe.untitledRecipe", defaultValue: "Untitled Recipe")
        static let statTime = String(localized: "createRecipe.statTime", defaultValue: "Time")
        static let statServings = String(localized: "createRecipe.statServings", defaultValue: "Serve")
        static let statLevel = String(localized: "createRecipe.statLevel", defaultValue: "Level")
        static let ingredientCount = String(localized: "createRecipe.ingredientCount", defaultValue: "%lld ingredients")
        static let stepCount = String(localized: "createRecipe.stepCount", defaultValue: "%lld steps")
        static let difficultyEasy = String(localized: "createRecipe.difficultyEasy", defaultValue: "Easy")
        static let difficultyMedium = String(localized: "createRecipe.difficultyMedium", defaultValue: "Medium")
        static let difficultyHard = String(localized: "createRecipe.difficultyHard", defaultValue: "Hard")
    }

    enum RecipeList {
        static let recentRecipes = String(localized: "recipeList.recentRecipes", defaultValue: "Recent Recipes")
        static let savedRecipes = String(localized: "recipeList.savedRecipes", defaultValue: "Saved Recipes")
        static let myRecipes = String(localized: "recipeList.myRecipes", defaultValue: "My Recipes")
    }

    enum SourceBadge {
        static let localTitle = String(localized: "sourceBadge.localTitle", defaultValue: "Local recipe")
        static let localDescription = String(localized: "sourceBadge.localDescription", defaultValue: "This recipe comes from CookSavvy's local recipe collection.")
        static let networkTitle = String(localized: "sourceBadge.networkTitle", defaultValue: "Network recipe")
        static let networkDescription = String(localized: "sourceBadge.networkDescription", defaultValue: "This recipe was fetched from an online recipe provider.")
        static let aiTitle = String(localized: "sourceBadge.aiTitle", defaultValue: "AI recipe")
        static let aiDescription = String(localized: "sourceBadge.aiDescription", defaultValue: "This recipe was generated with AI from your ingredients.")
        static let userTitle = String(localized: "sourceBadge.userTitle", defaultValue: "Your recipe")
        static let userDescription = String(localized: "sourceBadge.userDescription", defaultValue: "This recipe was created and saved by you.")
        static let accessibilityHint = String(localized: "sourceBadge.accessibilityHint", defaultValue: "Shows where this recipe came from")
        static let localShortLabel = String(localized: "sourceBadge.localShortLabel", defaultValue: "Local")
        static let networkShortLabel = String(localized: "sourceBadge.networkShortLabel", defaultValue: "Web")
        static let aiShortLabel = String(localized: "sourceBadge.aiShortLabel", defaultValue: "AI")
        static let userShortLabel = String(localized: "sourceBadge.userShortLabel", defaultValue: "Mine")
    }

    enum Onboarding {
        static let page1Title = String(localized: "onboarding.page1Title", defaultValue: "Dinner, Decided")
        static let page1Subtitle = String(localized: "onboarding.page1Subtitle", defaultValue: "Tell us what you have. We'll find what to make.")
        static let page2Title = String(localized: "onboarding.page2Title", defaultValue: "Snap Your Ingredients")
        static let page2Subtitle = String(localized: "onboarding.page2Subtitle", defaultValue: "Use your camera to add ingredients instantly")
        static let page3Title = String(localized: "onboarding.page3Title", defaultValue: "Cook with Confidence")
        static let page3Subtitle = String(localized: "onboarding.page3Subtitle", defaultValue: "Step-by-step guidance with built-in timers")
        static let getStarted = String(localized: "onboarding.getStarted", defaultValue: "Get Started")
        static let skip = String(localized: "onboarding.skip", defaultValue: "Skip")
    }

    enum ShoppingList {
        static let navigationTitle = String(localized: "shoppingList.navigationTitle", defaultValue: "Shopping List")
        static let clearDone = String(localized: "shoppingList.clearDone", defaultValue: "Clear Done")
        static let emptyTitle = String(localized: "shoppingList.emptyTitle", defaultValue: "Your list is empty")
        static let emptySubtitle = String(localized: "shoppingList.emptySubtitle", defaultValue: "Add missing ingredients from recipe details")
        static let addMissingToList = String(localized: "shoppingList.addMissingToList", defaultValue: "Add %lld Missing to List")
        static let otherGroup = String(localized: "shoppingList.otherGroup", defaultValue: "Other")
    }

    enum MoodFilter {
        static let cozy = String(localized: "moodFilter.cozy", defaultValue: "Cozy")
        static let fresh = String(localized: "moodFilter.fresh", defaultValue: "Fresh")
        static let bold = String(localized: "moodFilter.bold", defaultValue: "Bold")
        static let comfort = String(localized: "moodFilter.comfort", defaultValue: "Comfort")
        static let quick = String(localized: "moodFilter.quick", defaultValue: "Quick")
        static let refineByMood = String(localized: "moodFilter.refineByMood", defaultValue: "REFINE BY MOOD")
    }
}
