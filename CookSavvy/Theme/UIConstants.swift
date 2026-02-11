import SwiftUI

struct UI {

    struct Common {
        static let stackSpacing: CGFloat = 16
        static let contentSpacing: CGFloat = 16
        static let progressScale: CGFloat = 1.5
        static let placeholderCornerRadius: CGFloat = 6
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
    }

    struct SearchBar {
        static let verticalPadding: CGFloat = 9
        static let cornerRadius: CGFloat = 6
        static let borderWidth: CGFloat = 3
    }

    struct SelectedIngredient {
        static let cellSpacing: CGFloat = 0
        static let removeIconScale: CGFloat = 0.5
        static let cellPadding: CGFloat = 7
    }

    struct FindButton {
        static let cornerRadius: CGFloat = 8
        static let height: CGFloat = 40
    }

    struct SearchResults {
        static let ingredientLimit: Int = 3
    }

    struct RecipeDetails {
        static let imageHeight: CGFloat = 250
        static let cardCornerRadius: CGFloat = 10
        static let cardShadowRadius: CGFloat = 0.2
        static let cardShadowOffset: CGFloat = 0.2
        static let additionalInfoCellHeight: CGFloat = 50
        static let additionalInfoSlotsCount: Int = 4
        static let infoTitleSeparator = " "
        static let bulletPrefix = "• "
    }

    struct Settings {
        static let planInfoSpacing: CGFloat = 4
    }

    struct SourceBadge {
        static let iconSize: CGFloat = 10
        static let padding: CGFloat = 4
        static let cornerRadius: CGFloat = 6
        static let fontSize: CGFloat = 9
        static let spacing: CGFloat = 2
        static let backgroundOpacity: Double = 0.85
    }

    struct DiskImage {
        static let defaultPrefix = "Food Images/Food Images/"
        static let defaultExtension = ".jpg"
    }
}
