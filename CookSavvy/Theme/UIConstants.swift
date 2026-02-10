import SwiftUI

struct UI {

    struct Common {
        static let stackSpacing: CGFloat = 16
        static let contentSpacing: CGFloat = 16
        static let progressScale: CGFloat = 1.5
        static let placeholderCornerRadius: CGFloat = 6
        static let errorIcon = "exclamationmark.triangle"
        static let backButtonIcon = "chevron.left"
    }

    struct Tab {
        static let ingredientsTitle = "Ingredients"
        static let recentTitle = "Recent"
        static let favoritesTitle = "Favorites"
        static let settingsTitle = "Settings"
        static let ingredientsIcon = "carrot"
        static let recentIcon = "clock"
        static let favoritesIcon = "heart"
        static let settingsIcon = "gear"
    }

    struct RecipeCell {
        static let listRowSpacing: CGFloat = 18
        static let horizontalSpacing: CGFloat = 12
        static let imageSize: CGFloat = 70
        static let imageCornerRadius: CGFloat = 10
        static let contentSpacing: CGFloat = 8
        static let verticalPadding: CGFloat = 4
        static let titleLineLimit: Int = 2
        static let ingredientsSpacing: CGFloat = 6
        static let maxVisibleIngredients: Int = 3
        static let maxChipWidth: CGFloat = 100
        static let extraIngredientsPrefix = "+"
        static let spacerMinLength: CGFloat = 0
    }

    struct IngredientChip {
        static let lineLimit: Int = 1
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 5
        static let previewCount: Int = 10
    }

    struct IngredientsInput {
        static let backgroundCornerRadius: CGFloat = 10
        static let popoverWidth: CGFloat = 400
        static let popoverHeight: CGFloat = 300
        static let findButtonSpacerMinLength: CGFloat = 150
        static let fastGridSize: Int = 3
        static let fastCellCornerRadius: CGFloat = 6
        static let navigationTitle = "Ingredients Input"
        static let cameraPlaceholderText = "not implemented yet, close"
        static let loadingText = "Loading ingredients..."
        static let searchLoadingText = "Searching..."
        static let autocompleteSelectedIcon = "checkmark.circle"
    }

    struct SearchBar {
        static let verticalPadding: CGFloat = 9
        static let cornerRadius: CGFloat = 6
        static let borderWidth: CGFloat = 3
        static let placeholderText = "Type an ingredient"
        static let cameraIcon = "camera"
        static let magnifyingIcon = "magnifyingglass"
    }

    struct SelectedIngredient {
        static let cellSpacing: CGFloat = 0
        static let removeIconScale: CGFloat = 0.5
        static let cellPadding: CGFloat = 7
        static let removeIcon = "xmark"
    }

    struct FindButton {
        static let cornerRadius: CGFloat = 8
        static let height: CGFloat = 40
        static let title = "Find Recipes (2 ingredients)"
    }

    struct SearchResults {
        static let ingredientLimit: Int = 3
        static let preparingDatabaseText = "Preparing recipes database..."
        static let loadingText = "Loading recipes..."
        static let noResultsTitle = "No recipes found"
        static let noResultsSubtitle = "Try different ingredients"
        static let navigationTitle = "Recipe search result"
        static let noResultsIcon = "magnifyingglass"
        static let foundStringFormat = "Found %i recipes using %@"
    }

    struct RecipeDetails {
        static let imageHeight: CGFloat = 250
        static let cardCornerRadius: CGFloat = 10
        static let cardShadowRadius: CGFloat = 0.2
        static let cardShadowOffset: CGFloat = 0.2
        static let additionalInfoCellHeight: CGFloat = 50
        static let additionalInfoSlotsCount: Int = 4
        static let infoTitleSeparator = " "
        static let ingredientsTitle = "🛒 Ingredients"
        static let instructionsTitle = "🧑‍🍳 Instructions"
        static let bulletPrefix = "• "
        static let favoriteFilledIcon = "heart.fill"
        static let favoriteOutlineIcon = "heart"
    }

    struct Favorites {
        static let loadingText = "Loading favorites..."
        static let emptyTitle = "No favorite recipes"
        static let emptySubtitle = "Tap the heart icon on recipes to save them here"
        static let navigationTitle = "Favorites"
        static let emptyIcon = "heart"
        static let removeLabelTitle = "Remove"
        static let removeIcon = "heart.slash"
    }

    struct Recent {
        static let loadingText = "Loading recent recipes..."
        static let emptyTitle = "No recent recipes"
        static let emptySubtitle = "Recipes you view will appear here"
        static let navigationTitle = "Recent Recipes"
        static let emptyIcon = "clock"
    }

    struct Settings {
        static let planInfoSpacing: CGFloat = 4
        static let navigationTitle = "Settings"
        static let subscriptionHeaderTitle = "Subscription Plan"
        static let statisticsHeaderTitle = "Statistics"
        static let totalRecipesLabel = "Total Recipes"
        static let favoriteRecipesLabel = "Favorite Recipes"
        static let recentRecipesLabel = "Recent Recipes"
        static let dataManagementHeaderTitle = "Data Management"
        static let clearRecentButtonTitle = "Clear Recent Data"
        static let clearFavoritesButtonTitle = "Clear Favorites"
        static let dataManagementFooterText = "Clearing data cannot be undone"
        static let appInfoHeaderTitle = "App Information"
        static let versionLabel = "Version"
        static let buildLabel = "Build"
        static let planCheckmarkIcon = "checkmark.circle.fill"
        static let trashIcon = "trash"
        static let clearRecentAlertTitle = "Clear Recent Data?"
        static let clearFavoritesAlertTitle = "Clear Favorites?"
        static let alertCancelTitle = "Cancel"
        static let alertClearTitle = "Clear"
        static let clearRecentAlertMessage = "This will clear all recent ingredients, recipes, and searches. This action cannot be undone."
        static let clearFavoritesAlertMessage = "This will remove all favorited recipes. This action cannot be undone."
    }

    struct DiskImage {
        static let defaultPrefix = "Food Images/Food Images/"
        static let defaultExtension = ".jpg"
    }
}
