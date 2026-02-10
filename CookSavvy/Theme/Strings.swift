import Foundation

enum Strings {

    enum Common {
        static let ok = String(localized: "common.ok", defaultValue: "OK")
        static let cancel = String(localized: "common.cancel", defaultValue: "Cancel")
    }

    enum Tab {
        static let ingredients = String(localized: "tab.ingredients", defaultValue: "Ingredients")
        static let recent = String(localized: "tab.recent", defaultValue: "Recent")
        static let favorites = String(localized: "tab.favorites", defaultValue: "Favorites")
        static let settings = String(localized: "tab.settings", defaultValue: "Settings")
    }

    enum IngredientsInput {
        static let navigationTitle = String(localized: "ingredientsInput.navigationTitle", defaultValue: "Ingredients Input")
        static let cameraPlaceholder = String(localized: "ingredientsInput.cameraPlaceholder", defaultValue: "not implemented yet, close")
        static let loading = String(localized: "ingredientsInput.loading", defaultValue: "Loading ingredients...")
        static let searchLoading = String(localized: "ingredientsInput.searchLoading", defaultValue: "Searching...")
    }

    enum SearchBar {
        static let placeholder = String(localized: "searchBar.placeholder", defaultValue: "Type an ingredient")
    }

    enum FindButton {
        static let title = String(localized: "findButton.title", defaultValue: "Find Recipes (2 ingredients)")
    }

    enum SearchResults {
        static let preparingDatabase = String(localized: "searchResults.preparingDatabase", defaultValue: "Preparing recipes database...")
        static let loading = String(localized: "searchResults.loading", defaultValue: "Loading recipes...")
        static let noResultsTitle = String(localized: "searchResults.noResultsTitle", defaultValue: "No recipes found")
        static let noResultsSubtitle = String(localized: "searchResults.noResultsSubtitle", defaultValue: "Try different ingredients")
        static let navigationTitle = String(localized: "searchResults.navigationTitle", defaultValue: "Recipe search result")
        static let foundFormat = String(localized: "searchResults.foundFormat", defaultValue: "Found %lld recipes using %@")
    }

    enum RecipeDetails {
        static let ingredientsTitle = String(localized: "recipeDetails.ingredientsTitle", defaultValue: "🛒 Ingredients")
        static let instructionsTitle = String(localized: "recipeDetails.instructionsTitle", defaultValue: "🧑‍🍳 Instructions")
    }

    enum Favorites {
        static let loading = String(localized: "favorites.loading", defaultValue: "Loading favorites...")
        static let emptyTitle = String(localized: "favorites.emptyTitle", defaultValue: "No favorite recipes")
        static let emptySubtitle = String(localized: "favorites.emptySubtitle", defaultValue: "Tap the heart icon on recipes to save them here")
        static let navigationTitle = String(localized: "favorites.navigationTitle", defaultValue: "Favorites")
        static let removeLabel = String(localized: "favorites.removeLabel", defaultValue: "Remove")
    }

    enum Recent {
        static let loading = String(localized: "recent.loading", defaultValue: "Loading recent recipes...")
        static let emptyTitle = String(localized: "recent.emptyTitle", defaultValue: "No recent recipes")
        static let emptySubtitle = String(localized: "recent.emptySubtitle", defaultValue: "Recipes you view will appear here")
        static let navigationTitle = String(localized: "recent.navigationTitle", defaultValue: "Recent Recipes")
    }

    enum Settings {
        static let navigationTitle = String(localized: "settings.navigationTitle", defaultValue: "Settings")
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
        static let unlockTitle = String(localized: "upgrade.unlockTitle", defaultValue: "Unlock Premium Features")
        static let unlockSubtitle = String(localized: "upgrade.unlockSubtitle", defaultValue: "Get access to more recipes and AI-powered features")
        static let current = String(localized: "upgrade.current", defaultValue: "Current")
        static let subscribe = String(localized: "upgrade.subscribe", defaultValue: "Subscribe")
        static let purchaseFailed = String(localized: "upgrade.purchaseFailed", defaultValue: "Purchase Failed")
        static let unknownError = String(localized: "upgrade.unknownError", defaultValue: "An unknown error occurred")
    }
}
