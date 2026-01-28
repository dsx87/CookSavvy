import SwiftUI

struct UIConstants {
    static let statusStackSpacing: CGFloat = 16
    static let mainContentStackSpacing: CGFloat = 16
    static let statusProgressScale: CGFloat = 1.5
    static let recipeResultListRowSpacing: CGFloat = 18
    static let recipeCellHorizontalSpacing: CGFloat = 12
    static let recipeCellImageSize: CGFloat = 70
    static let recipeCellImageCornerRadius: CGFloat = 10
    static let recipeCellContentSpacing: CGFloat = 8
    static let recipeCellVerticalPadding: CGFloat = 4
    static let recipeTitleLineLimit: Int = 2
    static let ingredientChipLineLimit: Int = 1
    static let ingredientChipHorizontalPadding: CGFloat = 10
    static let ingredientChipVerticalPadding: CGFloat = 5
    static let recipeCellIngredientsSpacing: CGFloat = 6
    static let recipeCellMaxVisibleIngredients: Int = 3
    static let recipeCellMaxChipWidth: CGFloat = 100
    static let recipeCellExtraIngredientsPrefix = "+"
    static let emptyCountThreshold: Int = 0
    static let recipeCellSpacerMinLength: CGFloat = 0
    static let ingredientsInputBackgroundCornerRadius: CGFloat = 10
    static let ingredientsPopoverWidth: CGFloat = 400
    static let ingredientsPopoverHeight: CGFloat = 300
    static let ingredientsFindButtonSpacerMinLength: CGFloat = 150
    static let ingredientsFastGridSize: Int = 3
    static let ingredientsFastCellCornerRadius: CGFloat = 6
    static let searchBarVerticalPadding: CGFloat = 9
    static let searchBarCornerRadius: CGFloat = 6
    static let searchBarBorderWidth: CGFloat = 3
    static let selectedIngredientCellSpacing: CGFloat = 0
    static let selectedIngredientRemoveIconScale: CGFloat = 0.5
    static let selectedIngredientCellPadding: CGFloat = 7
    static let findRecipesButtonCornerRadius: CGFloat = 8
    static let findRecipesButtonHeight: CGFloat = 40
    static let placeholderCornerRadius: CGFloat = 6
    static let searchResultsIngredientLimit: Int = 3
    static let settingsPlanInfoSpacing: CGFloat = 4
    static let recipeDetailsImageHeight: CGFloat = 250
    static let recipeDetailsCardCornerRadius: CGFloat = 10
    static let recipeDetailsCardShadowRadius: CGFloat = 0.2
    static let recipeDetailsCardShadowOffset: CGFloat = 0.2
    static let recipeDetailsAdditionalInfoCellHeight: CGFloat = 50
    static let recipeAdditionalInfoSlotsCount: Int = 4
    static let recipeAdditionalInfoFirstIndex: Int = 0
    static let recipeAdditionalInfoSecondIndex: Int = 1
    static let recipeAdditionalInfoThirdIndex: Int = 2
    static let recipeAdditionalInfoFourthIndex: Int = 3
    static let recipeDetailsInfoTitleSeparator = " "
    static let ingredientChipPreviewCount: Int = 10

    static let tabIngredientsTitle = "Ingredients"
    static let tabRecentTitle = "Recent"
    static let tabFavoritesTitle = "Favorites"
    static let tabSettingsTitle = "Settings"
    static let tabIngredientsIconName = "carrot"
    static let tabRecentIconName = "clock"
    static let tabFavoritesIconName = "heart"
    static let tabSettingsIconName = "gear"

    static let ingredientsInputNavigationTitle = "Ingredients Input"
    static let ingredientsInputCameraPlaceholderText = "not implemented yet, close"
    static let ingredientsInputLoadingText = "Loading ingredients..."
    static let ingredientsInputSearchLoadingText = "Searching..."
    static let ingredientsSearchPlaceholderText = "Type an ingredient"
    static let ingredientsSearchCameraIconName = "camera"
    static let ingredientsSearchMagnifyingIconName = "magnifyingglass"
    static let ingredientsAutocompleteSelectedIconName = "checkmark.circle"
    static let selectedIngredientRemoveIconName = "xmark"
    static let findRecipesButtonTitle = "Find Recipes (2 ingredients)"

    static let recipesPreparingDatabaseText = "Preparing recipes database..."
    static let recipesLoadingText = "Loading recipes..."
    static let recipesNoResultsTitle = "No recipes found"
    static let recipesNoResultsSubtitle = "Try different ingredients"
    static let recipesNavigationTitle = "Recipe search result"
    static let errorIconName = "exclamationmark.triangle"
    static let recipesNoResultsIconName = "magnifyingglass"
    static let backButtonIconName = "chevron.left"

    static let searchResultsFoundPrefix = "Found "
    static let searchResultsFoundInfix = " recipes using "
    static let searchResultsIngredientSeparator = ","
    static let searchResultsEllipsis = "..."

    static let favoritesLoadingText = "Loading favorites..."
    static let favoritesEmptyTitle = "No favorite recipes"
    static let favoritesEmptySubtitle = "Tap the heart icon on recipes to save them here"
    static let favoritesNavigationTitle = "Favorites"
    static let favoritesEmptyIconName = "heart"
    static let favoritesRemoveLabelTitle = "Remove"
    static let favoritesRemoveIconName = "heart.slash"

    static let recentLoadingText = "Loading recent recipes..."
    static let recentEmptyTitle = "No recent recipes"
    static let recentEmptySubtitle = "Recipes you view will appear here"
    static let recentNavigationTitle = "Recent Recipes"
    static let recentEmptyIconName = "clock"

    static let settingsNavigationTitle = "Settings"
    static let settingsSubscriptionHeaderTitle = "Subscription Plan"
    static let settingsStatisticsHeaderTitle = "Statistics"
    static let settingsTotalRecipesLabel = "Total Recipes"
    static let settingsFavoriteRecipesLabel = "Favorite Recipes"
    static let settingsRecentRecipesLabel = "Recent Recipes"
    static let settingsDataManagementHeaderTitle = "Data Management"
    static let settingsClearRecentButtonTitle = "Clear Recent Data"
    static let settingsClearFavoritesButtonTitle = "Clear Favorites"
    static let settingsDataManagementFooterText = "Clearing data cannot be undone"
    static let settingsAppInfoHeaderTitle = "App Information"
    static let settingsVersionLabel = "Version"
    static let settingsBuildLabel = "Build"
    static let settingsPlanCheckmarkIconName = "checkmark.circle.fill"
    static let settingsTrashIconName = "trash"
    static let settingsClearRecentAlertTitle = "Clear Recent Data?"
    static let settingsClearFavoritesAlertTitle = "Clear Favorites?"
    static let settingsAlertCancelTitle = "Cancel"
    static let settingsAlertClearTitle = "Clear"
    static let settingsClearRecentAlertMessage = "This will clear all recent ingredients, recipes, and searches. This action cannot be undone."
    static let settingsClearFavoritesAlertMessage = "This will remove all favorited recipes. This action cannot be undone."

    static let recipeDetailsIngredientsTitle = "🛒 Ingredients"
    static let recipeDetailsInstructionsTitle = "🧑‍🍳 Instructions"
    static let recipeDetailsBulletPrefix = "• "
    static let recipeDetailsFavoriteFilledIconName = "heart.fill"
    static let recipeDetailsFavoriteOutlineIconName = "heart"

    static let asyncImageDefaultPrefix = "Food Images/Food Images/"
    static let asyncImageDefaultExtension = ".jpg"

    
}
