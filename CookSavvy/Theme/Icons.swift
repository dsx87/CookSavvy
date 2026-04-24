import Foundation

/// Centralized SF Symbol name constants for the CookSavvy app, organized by screen or feature domain.
///
/// Using typed constants avoids typo-induced crashes at runtime and makes global symbol
/// changes easy to apply. Access constants as `Icons.Screen.symbolName`.
enum Icons {

    /// Icons shared across multiple screens — errors and back navigation.
    enum Common {
        static let error = "exclamationmark.triangle"
        static let backButton = "chevron.left"
    }

    /// Icons for the main tab bar items.
    enum Tab {
        static let discover = "compass.drawing"
        static let myKitchen = "fork.knife.circle.fill"
    }

    /// Icons used within the ingredient search bar.
    enum SearchBar {
        static let camera = "camera"
        static let magnifying = "magnifyingglass"
        static let clear = "xmark.circle.fill"
    }

    /// Icons for selected ingredient chips (remove action).
    enum SelectedIngredient {
        static let remove = "xmark"
    }

    /// Icons for the Recipe Details screen (favorite toggle and share).
    enum RecipeDetails {
        static let favoriteFilled = "heart.fill"
        static let favoriteOutline = "heart"
        static let share = "square.and.arrow.up"
    }

    /// Icons for the Settings screen.
    enum Settings {
        static let planCheckmark = "checkmark.circle.fill"
        static let trash = "trash"
        static let crown = "crown.fill"
        static let chevronRight = "chevron.right"
        static let manageSubscription = "arrow.up.forward.app"
    }

    /// Icons for the Camera ingredient-detection screen.
    enum Camera {
        static let camera = "camera.fill"
        static let warning = "exclamationmark.triangle"
        static let errorCircle = "xmark.circle.fill"
        static let close = "xmark"
    }

    /// Icons for the Upgrade / subscription paywall screen.
    enum Upgrade {
        static let crown = "crown.fill"
        static let checkmark = "checkmark.circle.fill"
    }

    /// Icons for the Discover tab (ingredient selection and recipe results states).
    enum Discover {
        static let error = "exclamationmark.triangle.fill"
        static let clock = "clock"
        static let bookmark = "bookmark"
        static let bookmarkFill = "bookmark.fill"
        static let plus = "plus"
        static let chevronRight = "chevron.right"
        static let matchBadge = "checkmark.seal"
        static let matchInfo = "info.circle"
        static let useItAll = "checkmark.circle.fill"
        static let flame = "flame"
        static let person2 = "person.2"
        static let chartBar = "chart.bar"
        static let idea = "lightbulb.fill"
        static let emptyState = "refrigerator"
        static let noResults = "magnifyingglass"
        static let badgeQuick = "hare"
        static let badgeEasy = "hand.thumbsup"
        static let badgeBeginner = "star.circle"
    }

    /// Icons for the My Kitchen (Journey) screen.
    enum Journey {
        static let settings = "gear"
        static let forkKnife = "fork.knife"
        static let flame = "flame"
        static let clock = "clock"
        static let cookAgain = "arrow.clockwise"
        static let plus = "plus"
        static let cart = "cart.fill"
        static let pencil = "pencil"
        static let checkmark = "checkmark"
        static let star = "star.fill"
        static let leaf = "leaf.fill"
        static let savings = "dollarsign.circle.fill"
        static let chevronDown = "chevron.down"
        static let chevronUp = "chevron.up"
    }

    /// Icons for Cook Mode — the full-screen step-by-step cooking flow.
    enum CookMode {
        static let close = "xmark"
        static let previous = "chevron.left"
        static let next = "chevron.right"
        static let checkmark = "checkmark"
        static let play = "play.fill"
        static let pause = "pause.fill"
        static let timer = "timer"
    }

    /// Icons for the Create Recipe wizard.
    enum CreateRecipe {
        static let close = "xmark"
        static let minus = "minus.circle"
        static let plus = "plus"
        static let dragHandle = "line.3.horizontal"
        static let timer = "timer"
        static let minusFilled = "minus.circle.fill"
        static let plusFilled = "plus.circle.fill"
        static let list = "list.bullet"
        static let number = "number"
    }

    /// Icons for the Shopping List sheet.
    enum ShoppingList {
        static let cart = "cart"
        static let cartBadgePlus = "cart.badge.plus"
        static let checkCircleFill = "checkmark.circle.fill"
        static let circle = "circle"
        static let trash = "trash"
    }

    /// Icons representing dietary restriction types.
    ///
    /// Symbol choices reflect semantic meaning: `glutenFree` uses an exclusion (`xmark.circle.fill`),
    /// and `nutFree` uses a warning triangle (`exclamationmark.triangle.fill`) to convey allergen severity.
    enum Dietary {
        static let vegetarian = "leaf.fill"
        static let vegan = "leaf.circle.fill"
        static let glutenFree = "xmark.circle.fill"
        static let dairyFree = "drop.fill"
        static let nutFree = "exclamationmark.triangle.fill"
        static let halal = "checkmark.seal.fill"
        static let kosher = "star.circle.fill"
    }

    /// Icons for Sign in with Apple and account management in Settings.
    enum Auth {
        static let applelogo = "apple.logo"
        static let personCircle = "person.crop.circle"
        static let signOut = "rectangle.portrait.and.arrow.right"
        static let checkmarkShield = "checkmark.shield"
    }

    /// Icons representing recipe mood filter options on the Discover results state.
    enum Mood {
        static let cozy = "flame"
        static let fresh = "leaf"
        static let bold = "bolt.fill"
        static let comfort = "heart.fill"
        static let quick = "hare"
    }
}
