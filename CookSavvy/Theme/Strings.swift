import Foundation

/// Centralized localized string constants for the CookSavvy app, organized by screen or feature domain.
///
/// Each nested enum corresponds to a screen or feature area and vends `String` values backed by
/// `Localizable.xcstrings` (Xcode 15+ String Catalog) via `String(localized:defaultValue:)`.
/// Access strings as `Strings.Screen.key` — the localization key is the first argument, and
/// `defaultValue` serves as the English fallback.
enum Strings {

    /// Strings shared across multiple screens — standard actions and time formatting.
    enum Common {
        static let ok = String(localized: "common.ok", defaultValue: "OK")
        static let cancel = String(localized: "common.cancel", defaultValue: "Cancel")
        static let minutesShort = String(localized: "common.minutesShort", defaultValue: "%lld min")
        static let minutesCompact = String(localized: "common.minutesCompact", defaultValue: "%lldm")
    }

    /// User-facing error messages shown in alerts and inline error states.
    enum Errors {
        static let loadFailed = String(localized: "errors.loadFailed", defaultValue: "We couldn't load this right now.")
        static let actionFailed = String(localized: "errors.actionFailed", defaultValue: "That action didn't go through. Please try again.")
        static let favoriteFailed = String(localized: "errors.favoriteFailed", defaultValue: "We couldn't update favorites right now.")
        static let shoppingListAddFailed = String(localized: "errors.shoppingListAddFailed", defaultValue: "We couldn't add those items to your shopping list.")
        static let shoppingListLoadFailed = String(localized: "errors.shoppingListLoadFailed", defaultValue: "We couldn't load your shopping list.")
        static let shoppingListActionFailed = String(localized: "errors.shoppingListActionFailed", defaultValue: "We couldn't update your shopping list right now.")
        static let settingsLoadFailed = String(localized: "errors.settingsLoadFailed", defaultValue: "We couldn't load your settings right now.")
        static let clearDataFailed = String(localized: "errors.clearDataFailed", defaultValue: "We couldn't clear that data right now.")
        static let cookModeSaveFailed = String(localized: "errors.cookModeSaveFailed", defaultValue: "We couldn't save your cooking progress.")
        static let journeyLoadFailed = String(localized: "errors.journeyLoadFailed", defaultValue: "We couldn't load your kitchen activity right now.")
        static let errorAlertTitle = String(localized: "errors.errorAlertTitle", defaultValue: "Something went wrong")
    }

    /// Strings for the blocking startup-failure view shown when the database cannot be opened.
    enum Startup {
        static let title = String(localized: "startup.title", defaultValue: "CookSavvy couldn't start")
        static let message = String(localized: "startup.message", defaultValue: "The app could not open its local database. Please restart the app.")
    }

    /// Tab bar item labels.
    enum Tab {
        static let discover = String(localized: "tab.discover", defaultValue: "Discover")
        static let journey = String(localized: "tab.journey", defaultValue: "My Kitchen")
    }

    /// Strings for the Recipe Details screen.
    enum RecipeDetails {
        static let ingredientsTitle = String(localized: "recipeDetails.ingredientsTitle", defaultValue: "🛒 Ingredients")
        static let instructionsTitle = String(localized: "recipeDetails.instructionsTitle", defaultValue: "🧑‍🍳 Instructions")
        static let youHave = String(localized: "recipeDetails.youHave", defaultValue: "You have this")
        static let youNeed = String(localized: "recipeDetails.youNeed", defaultValue: "You need this")
        static let byAuthor = String(localized: "recipeDetails.byAuthor", defaultValue: "by %@")
        static let sectionIngredients = String(localized: "recipeDetails.sectionIngredients", defaultValue: "INGREDIENTS")
        static let sectionSteps = String(localized: "recipeDetails.sectionSteps", defaultValue: "STEPS")
    }

    /// Strings rendered into recipe share-card images.
    enum ShareCard {
        static let brand = String(localized: "shareCard.brand", defaultValue: "CookSavvy")
        static let ingredientsCount = String(localized: "shareCard.ingredientsCount", defaultValue: "%lld ingredients")
    }

    /// Strings for the Settings screen, including appearance, subscription, data management, and app info sections.
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

    /// Strings for the Camera ingredient-detection screen.
    enum Camera {
        static let accessRequired = String(localized: "camera.accessRequired", defaultValue: "Camera Access Required")
        static let accessDescription = String(localized: "camera.accessDescription", defaultValue: "Please allow camera access in Settings to scan ingredients")
        static let openSettings = String(localized: "camera.openSettings", defaultValue: "Open Settings")
        static let detecting = String(localized: "camera.detecting", defaultValue: "Detecting ingredients...")
        static let noIngredientsTitle = String(localized: "camera.noIngredientsTitle", defaultValue: "No Ingredients Found")
        static let noIngredientsSubtitle = String(localized: "camera.noIngredientsSubtitle", defaultValue: "Try taking another photo with ingredients clearly visible")
        static let tryAgain = String(localized: "camera.tryAgain", defaultValue: "Try Again")
    }

    /// Strings for the Upgrade / subscription paywall screen.
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

    /// Strings for the Discover tab (ingredient selection and recipe results states).
    ///
    /// Time-of-day greetings, ingredient grid labels, match badge text, collection
    /// titles, and empty/no-results state copy are all housed here.
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
        static let collectionsSection = String(localized: "discover.collectionsSection", defaultValue: "THIS WEEK'S COLLECTIONS")
        static let collection5Ingredient = String(localized: "discover.collection5Ingredient", defaultValue: "5-Ingredient Dinners")
        static let collection5IngredientSubtitle = String(localized: "discover.collection5IngredientSubtitle", defaultValue: "Simple meals, big flavour")
        static let collection30Min = String(localized: "discover.collection30Min", defaultValue: "30-Minute Meals")
        static let collection30MinSubtitle = String(localized: "discover.collection30MinSubtitle", defaultValue: "On the table, fast")
        static let collectionOnePot = String(localized: "discover.collectionOnePot", defaultValue: "One-Pot Wonders")
        static let collectionOnePotSubtitle = String(localized: "discover.collectionOnePotSubtitle", defaultValue: "Less washing up")
        static let collectionBudget = String(localized: "discover.collectionBudget", defaultValue: "Budget Friendly")
        static let collectionBudgetSubtitle = String(localized: "discover.collectionBudgetSubtitle", defaultValue: "Big taste, small cost")
        static let collectionComfort = String(localized: "discover.collectionComfort", defaultValue: "Comfort Classics")
        static let collectionComfortSubtitle = String(localized: "discover.collectionComfortSubtitle", defaultValue: "Tried and trusted favourites")
        static let collectionLight = String(localized: "discover.collectionLight", defaultValue: "Light & Fresh")
        static let collectionLightSubtitle = String(localized: "discover.collectionLightSubtitle", defaultValue: "Clean and vibrant eats")
        static let emptyStateTitle = String(localized: "discover.emptyStateTitle", defaultValue: "Your fridge is waiting")
        static let emptyStateSubtitle = String(localized: "discover.emptyStateSubtitle", defaultValue: "Scan your fridge or pick ingredients below to rescue dinner")
        static let noResultsTitle = String(localized: "discover.noResultsTitle", defaultValue: "No recipes found")
        static let noResultsSubtitle = String(localized: "discover.noResultsSubtitle", defaultValue: "Try removing an ingredient or changing your mood filter")
        static let badgeQuick = String(localized: "discover.badgeQuick", defaultValue: "Quick")
        static let badgeEasy = String(localized: "discover.badgeEasy", defaultValue: "Easy")
        static let badgeBeginner = String(localized: "discover.badgeBeginner", defaultValue: "Beginner")
    }

    /// Strings for the My Kitchen (Journey) screen, including stats, achievements, shopping list shortcuts, and account section.
    enum Journey {
        static let navigationTitle = String(localized: "journey.navigationTitle", defaultValue: "My Kitchen")
        static let recipesCooked = String(localized: "journey.recipesCooked", defaultValue: "Recipes\nCooked")
        static let dayStreak = String(localized: "journey.dayStreak", defaultValue: "Day\nStreak")
        static let ingredientsRescued = String(localized: "journey.ingredientsRescued", defaultValue: "Ingredients\nRescued")
        static let hoursCooking = String(localized: "journey.hoursCooking", defaultValue: "Time\nCooked")
        static let savedRecipes = String(localized: "journey.savedRecipes", defaultValue: "SAVED RECIPES")
        static let savedRecipesEmpty = String(localized: "journey.savedRecipesEmpty", defaultValue: "Start saving recipes to see them here.")
        static let recentCooks = String(localized: "journey.recentCooks", defaultValue: "RECENT COOKS")
        static let cookAgain = String(localized: "journey.cookAgain", defaultValue: "Cook Again")
        static let cookAgainErrorTitle = String(localized: "journey.cookAgainErrorTitle", defaultValue: "Recipe Unavailable")
        static let cookAgainErrorMessage = String(localized: "journey.cookAgainErrorMessage", defaultValue: "This recipe couldn't be loaded right now. Please try again later.")
        static let shoppingList = String(localized: "journey.shoppingList", defaultValue: "SHOPPING LIST")
        static let shoppingListReady = String(localized: "journey.shoppingListReady", defaultValue: "Review missing ingredients before your next store run.")
        static let shoppingListPremium = String(localized: "journey.shoppingListPremium", defaultValue: "Unlock the shopping list to keep missing ingredients organized by recipe.")
        static let openList = String(localized: "journey.openList", defaultValue: "Open List")
        static let unlockShoppingList = String(localized: "journey.unlockShoppingList", defaultValue: "Unlock Shopping List")
        static let kitchenStats = String(localized: "journey.kitchenStats", defaultValue: "KITCHEN STATS")
        static let myRecipes = String(localized: "journey.myRecipes", defaultValue: "MY RECIPES")
        static let addRecipe = String(localized: "journey.addRecipe", defaultValue: "Add Recipe")
        static let recipeCount = String(localized: "journey.recipeCount", defaultValue: "%lld recipes")
        static let allTime = String(localized: "journey.allTime", defaultValue: "ALL TIME")
        static let thisWeek = String(localized: "journey.thisWeek", defaultValue: "THIS WEEK")
        static let achievements = String(localized: "journey.achievements", defaultValue: "ACHIEVEMENTS")
        static let milestones = String(localized: "journey.milestones", defaultValue: "MILESTONES")
        static let milestonesEarned = String(localized: "journey.milestonesEarned", defaultValue: "%lld of %lld earned")
        static let achievementsSummary = String(localized: "journey.achievementsSummary", defaultValue: "Keep progress light. Anti-waste wins stay front and center.")
        static let showAllMilestones = String(localized: "journey.showAllMilestones", defaultValue: "Show All")
        static let hideMilestones = String(localized: "journey.hideMilestones", defaultValue: "Hide")
        static let recentActivity = String(localized: "journey.recentActivity", defaultValue: "RECENT ACTIVITY")
        static let seeAll = String(localized: "journey.seeAll", defaultValue: "See All")
        static let shareCreations = String(localized: "journey.shareCreations", defaultValue: "Share your own creations")
        static let thisMonth = String(localized: "journey.thisMonth", defaultValue: "THIS MONTH")
        static let monthlyMeals = String(localized: "journey.monthlyMeals", defaultValue: "Meals\nCooked")
        static let monthlyRescued = String(localized: "journey.monthlyRescued", defaultValue: "Ingredients\nRescued")
        static let signIn = String(localized: "journey.signIn", defaultValue: "Sign In")
        static let accountSecured = String(localized: "journey.accountSecured", defaultValue: "Your recipes and preferences are backed up")
    }

    /// Strings for Cook Mode — the full-screen step-by-step cooking flow with timer and rating prompt.
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

    /// Strings for the five-step Create Recipe wizard (name, ingredients, steps, details, review).
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

    /// Strings for the Recipe List "See All" destination screen.
    enum RecipeList {
        static let recentRecipes = String(localized: "recipeList.recentRecipes", defaultValue: "Recent Recipes")
        static let savedRecipes = String(localized: "recipeList.savedRecipes", defaultValue: "Saved Recipes")
        static let myRecipes = String(localized: "recipeList.myRecipes", defaultValue: "My Recipes")
    }

    /// Strings for the first-launch Onboarding flow (intro pages, camera scan page, permission denied state).
    enum Onboarding {
        static let page1Title = String(localized: "onboarding.page1Title", defaultValue: "Dinner, Decided")
        static let page1Subtitle = String(localized: "onboarding.page1Subtitle", defaultValue: "Tell us what you have. We'll find what to make.")
        static let page2Title = String(localized: "onboarding.page2Title", defaultValue: "Snap Your Ingredients")
        static let page2Subtitle = String(localized: "onboarding.page2Subtitle", defaultValue: "Use your camera to add ingredients instantly")
        static let scanPageTitle = String(localized: "onboarding.scanPageTitle", defaultValue: "Let's See What You've Got")
        static let scanPageSubtitle = String(localized: "onboarding.scanPageSubtitle", defaultValue: "Point your camera at any ingredients")
        static let detectedTitle = String(localized: "onboarding.detectedTitle", defaultValue: "Ingredients Found!")
        static let typeInstead = String(localized: "onboarding.typeInstead", defaultValue: "Type ingredients instead")
        static let openSettings = String(localized: "onboarding.openSettings", defaultValue: "Open Settings")
        static let cameraDeniedTitle = String(localized: "onboarding.cameraDeniedTitle", defaultValue: "Camera Access Needed")
        static let cameraDeniedSubtitle = String(localized: "onboarding.cameraDeniedSubtitle", defaultValue: "Allow camera access to scan ingredients, or type them manually")
        static let scanning = String(localized: "onboarding.scanning", defaultValue: "Looking for ingredients…")
        static let noIngredientsTitle = String(localized: "onboarding.noIngredientsTitle", defaultValue: "No ingredients found")
        static let noIngredientsSubtitle = String(localized: "onboarding.noIngredientsSubtitle", defaultValue: "Try again with your ingredients clearly visible")
        static let errorTitle = String(localized: "onboarding.errorTitle", defaultValue: "Something went wrong")
        static let next = String(localized: "onboarding.next", defaultValue: "Next")
        static let getStarted = String(localized: "onboarding.getStarted", defaultValue: "Get Started")
        static let skip = String(localized: "onboarding.skip", defaultValue: "Skip")
    }

    /// Strings for the Shopping List sheet (navigation, empty state, item grouping).
    enum ShoppingList {
        static let navigationTitle = String(localized: "shoppingList.navigationTitle", defaultValue: "Shopping List")
        static let clearDone = String(localized: "shoppingList.clearDone", defaultValue: "Clear Done")
        static let emptyTitle = String(localized: "shoppingList.emptyTitle", defaultValue: "Your list is empty")
        static let emptySubtitle = String(localized: "shoppingList.emptySubtitle", defaultValue: "Add missing ingredients from recipe details")
        static let addMissingToList = String(localized: "shoppingList.addMissingToList", defaultValue: "Add %lld Missing to List")
        static let otherGroup = String(localized: "shoppingList.otherGroup", defaultValue: "Other")
    }

    /// Strings for the Dietary Preferences section in Settings.
    enum Dietary {
        static let sectionTitle = String(localized: "dietary.sectionTitle", defaultValue: "Dietary Preferences")
        static let vegetarian = String(localized: "dietary.vegetarian", defaultValue: "Vegetarian")
        static let vegetarianDescription = String(localized: "dietary.vegetarianDescription", defaultValue: "No meat or fish")
        static let vegan = String(localized: "dietary.vegan", defaultValue: "Vegan")
        static let veganDescription = String(localized: "dietary.veganDescription", defaultValue: "No animal products")
        static let glutenFree = String(localized: "dietary.glutenFree", defaultValue: "Gluten Free")
        static let glutenFreeDescription = String(localized: "dietary.glutenFreeDescription", defaultValue: "No wheat, barley, or rye")
        static let dairyFree = String(localized: "dietary.dairyFree", defaultValue: "Dairy Free")
        static let dairyFreeDescription = String(localized: "dietary.dairyFreeDescription", defaultValue: "No milk or dairy products")
        static let nutFree = String(localized: "dietary.nutFree", defaultValue: "Nut Free")
        static let nutFreeDescription = String(localized: "dietary.nutFreeDescription", defaultValue: "No nuts or peanuts")
        static let halal = String(localized: "dietary.halal", defaultValue: "Halal")
        static let halalDescription = String(localized: "dietary.halalDescription", defaultValue: "No pork or alcohol")
        static let kosher = String(localized: "dietary.kosher", defaultValue: "Kosher")
        static let kosherDescription = String(localized: "dietary.kosherDescription", defaultValue: "No pork or shellfish")
        static let sectionFooter = String(localized: "dietary.sectionFooter", defaultValue: "Active filters are applied to recipe search results.")
    }

    /// Strings for the mood filter pill row on the Discover results state.
    enum MoodFilter {
        static let cozy = String(localized: "moodFilter.cozy", defaultValue: "Cozy")
        static let fresh = String(localized: "moodFilter.fresh", defaultValue: "Fresh")
        static let bold = String(localized: "moodFilter.bold", defaultValue: "Bold")
        static let comfort = String(localized: "moodFilter.comfort", defaultValue: "Comfort")
        static let quick = String(localized: "moodFilter.quick", defaultValue: "Quick")
        static let refineByMood = String(localized: "moodFilter.refineByMood", defaultValue: "REFINE BY MOOD")
    }

    /// Strings for result filters on the Discover results state.
    enum RecipeFilter {
        static let filterByTime = String(localized: "recipeFilter.filterByTime", defaultValue: "FILTER BY TIME")
        static let filterByDifficulty = String(localized: "recipeFilter.filterByDifficulty", defaultValue: "FILTER BY DIFFICULTY")
        static let quick = String(localized: "recipeFilter.quick", defaultValue: "Quick")
        static let mediumTime = String(localized: "recipeFilter.mediumTime", defaultValue: "30-60 min")
        static let long = String(localized: "recipeFilter.long", defaultValue: "60+ min")
        static let easy = String(localized: "recipeFilter.easy", defaultValue: "Easy")
        static let mediumDifficulty = String(localized: "recipeFilter.mediumDifficulty", defaultValue: "Medium")
        static let hard = String(localized: "recipeFilter.hard", defaultValue: "Hard")
    }

    /// Strings for Sign in with Apple and account management in Settings.
    enum Auth {
        static let accountHeader = String(localized: "auth.accountHeader", defaultValue: "Account")
        static let signInWithApple = String(localized: "auth.signInWithApple", defaultValue: "Sign in with Apple")
        static let signInSubtitle = String(localized: "auth.signInSubtitle", defaultValue: "Back up your preferences and secure your account")
        static let signOut = String(localized: "auth.signOut", defaultValue: "Sign Out")
        static let signOutConfirmTitle = String(localized: "auth.signOutConfirmTitle", defaultValue: "Sign Out?")
        static let signOutConfirmMessage = String(localized: "auth.signOutConfirmMessage", defaultValue: "You'll continue as a guest. Your local recipes and favorites will stay on this device.")
        static let signedInAs = String(localized: "auth.signedInAs", defaultValue: "Signed in with Apple")
        static let guestAccount = String(localized: "auth.guestAccount", defaultValue: "Guest")
        static let signingIn = String(localized: "auth.signingIn", defaultValue: "Signing in…")
        static let signOutGuestFailed = String(localized: "auth.signOutGuestFailed", defaultValue: "You've been signed out, but we couldn't restore a guest session. Online features may be unavailable until you're back online.")
    }

    /// Accessibility labels for VoiceOver and assistive technology support, organized by interaction type.
    enum Accessibility {
        static let ingredientSelected = String(localized: "accessibility.ingredientSelected", defaultValue: "%@, selected")
        static let ingredientNotSelected = String(localized: "accessibility.ingredientNotSelected", defaultValue: "%@, double tap to add")
        static let moodSelected = String(localized: "accessibility.moodSelected", defaultValue: "%@ mood, selected")
        static let moodNotSelected = String(localized: "accessibility.moodNotSelected", defaultValue: "%@ mood, double tap to filter")
        static let categorySelected = String(localized: "accessibility.categorySelected", defaultValue: "%@ category, selected")
        static let categoryNotSelected = String(localized: "accessibility.categoryNotSelected", defaultValue: "%@ category")
        static let achievementUnlocked = String(localized: "accessibility.achievementUnlocked", defaultValue: "%@ achievement, unlocked")
        static let achievementProgress = String(localized: "accessibility.achievementProgress", defaultValue: "%@ achievement, %lld of %lld progress")
        static let scanCamera = String(localized: "accessibility.scanCamera", defaultValue: "Scan ingredients with camera")
        static let timerRemaining = String(localized: "accessibility.timerRemaining", defaultValue: "Timer: %@ remaining")
        static let stepOf = String(localized: "accessibility.stepOf", defaultValue: "Step %lld of %lld")
        static let rating = String(localized: "accessibility.rating", defaultValue: "Rating: %@ out of 5 stars")
        static let addMoreIngredients = String(localized: "accessibility.addMoreIngredients", defaultValue: "Add more ingredients")
        static let closeButton = String(localized: "accessibility.closeButton", defaultValue: "Close")
        static let addToFavorites = String(localized: "accessibility.addToFavorites", defaultValue: "Add to favorites")
        static let removeFromFavorites = String(localized: "accessibility.removeFromFavorites", defaultValue: "Remove from favorites")
        static let shareRecipe = String(localized: "accessibility.shareRecipe", defaultValue: "Share recipe")
        static let clearSearch = String(localized: "accessibility.clearSearch", defaultValue: "Clear search")
        static let useItAllActive = String(localized: "accessibility.useItAllActive", defaultValue: "Use It All filter, active")
        static let useItAllInactive = String(localized: "accessibility.useItAllInactive", defaultValue: "Use It All filter, inactive")
        static let filterSelected = String(localized: "accessibility.filterSelected", defaultValue: "%@ filter, selected")
        static let filterNotSelected = String(localized: "accessibility.filterNotSelected", defaultValue: "%@ filter, double tap to apply")
        static let weekdayActive = String(localized: "accessibility.weekdayActive", defaultValue: "%@, cooked")
        static let weekdayInactive = String(localized: "accessibility.weekdayInactive", defaultValue: "%@, no activity")
        static let settingsButton = String(localized: "accessibility.settingsButton", defaultValue: "Settings")
        static let previousStep = String(localized: "accessibility.previousStep", defaultValue: "Previous step")
        static let nextStep = String(localized: "accessibility.nextStep", defaultValue: "Next step")
        static let createRecipe = String(localized: "accessibility.createRecipe", defaultValue: "Create new recipe")
        static let removeDietaryRestriction = String(localized: "accessibility.removeDietaryRestriction", defaultValue: "Remove %@ filter")
        static let onboardingPage = String(localized: "accessibility.onboardingPage", defaultValue: "Page %lld of %lld")
        static let removeIngredient = String(localized: "accessibility.removeIngredient", defaultValue: "Remove %@")
        static let checkItem = String(localized: "accessibility.checkItem", defaultValue: "Check %@")
        static let uncheckItem = String(localized: "accessibility.uncheckItem", defaultValue: "Uncheck %@")
    }
}
