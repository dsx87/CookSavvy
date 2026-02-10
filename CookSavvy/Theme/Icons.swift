import Foundation

enum Icons {

    enum Common {
        static let error = "exclamationmark.triangle"
        static let backButton = "chevron.left"
    }

    enum Tab {
        static let ingredients = "carrot"
        static let recent = "clock"
        static let favorites = "heart"
        static let settings = "gear"
    }

    enum IngredientsInput {
        static let autocompleteSelected = "checkmark.circle"
    }

    enum SearchBar {
        static let camera = "camera"
        static let magnifying = "magnifyingglass"
    }

    enum SelectedIngredient {
        static let remove = "xmark"
    }

    enum SearchResults {
        static let noResults = "magnifyingglass"
    }

    enum RecipeDetails {
        static let favoriteFilled = "heart.fill"
        static let favoriteOutline = "heart"
    }

    enum Favorites {
        static let empty = "heart"
        static let remove = "heart.slash"
    }

    enum Recent {
        static let empty = "clock"
    }

    enum Settings {
        static let planCheckmark = "checkmark.circle.fill"
        static let trash = "trash"
        static let crown = "crown.fill"
        static let chevronRight = "chevron.right"
        static let manageSubscription = "arrow.up.forward.app"
    }

    enum Camera {
        static let camera = "camera.fill"
        static let warning = "exclamationmark.triangle"
        static let errorCircle = "xmark.circle.fill"
        static let close = "xmark"
    }

    enum Upgrade {
        static let crown = "crown.fill"
        static let checkmark = "checkmark.circle.fill"
    }
}
