import SwiftUI

/// Centralised layout constants for the CookSavvy app.
///
/// All magic numbers — padding, spacing, sizes, opacities, and animation durations — live
/// inside domain-specific nested structs so every screen draws from a single source of truth.
/// Access constants as `UI.Domain.constant`, e.g. `UI.Common.horizontalPadding`.
struct UI {

    // MARK: - Fonts

    /// Typography constants — a curated set of shared `Font` values for the app.
    ///
    /// Fixed-size fonts are used for most text. `bodyScaled` and `stepContent` use semantic
    /// system fonts to honour the user's Dynamic Type accessibility size preference.
    struct Fonts {
        // Titles
        static let heroTitle: Font = .system(size: 34, weight: .bold, design: .rounded)
        static let largeTitle: Font = .system(size: 28, weight: .bold, design: .rounded)
        static let title: Font = .system(size: 22, weight: .bold, design: .rounded)
        static let sectionTitle: Font = .system(size: 15, weight: .bold, design: .rounded)
        static let recipeRowTitle: Font = .system(size: 16, weight: .bold, design: .rounded)
        // Body
        static let body: Font = .system(size: 15)
        static let bodyRounded: Font = .system(size: 15, design: .rounded)
        static let bodySemibold: Font = .system(size: 15, weight: .semibold, design: .rounded)
        // Accessibility-scaled: use semantic system fonts so Dynamic Type applies
        static let bodyScaled: Font = .body
        static let stepContent: Font = .title2
        // Captions
        static let caption: Font = .system(size: 13)
        static let captionSemibold: Font = .system(size: 13, weight: .semibold, design: .rounded)
        static let captionBold: Font = .system(size: 13, weight: .bold, design: .rounded)
        static let smallCaption: Font = .system(size: 12)
        static let smallCaptionBold: Font = .system(size: 12, weight: .bold, design: .rounded)
        static let smallCaptionSemibold: Font = .system(size: 12, weight: .semibold, design: .rounded)
        static let smallCaptionMedium: Font = .system(size: 12, weight: .medium, design: .rounded)
        static let tinyCaption: Font = .system(size: 11)
        static let tinyCaptionMedium: Font = .system(size: 11, weight: .medium, design: .rounded)
        static let micro: Font = .system(size: 10)
        static let microBold: Font = .system(size: 9, weight: .bold)
        // Buttons
        static let buttonLabel: Font = .system(size: 17, weight: .bold, design: .rounded)
        static let buttonIcon: Font = .system(size: 16, weight: .bold)
        static let smallButtonIcon: Font = .system(size: 14, weight: .bold)
        static let smallButton: Font = .system(size: 14, weight: .semibold, design: .rounded)
        // Icons
        static let iconMedium: Font = .system(size: 18, weight: .medium)
        static let iconBold: Font = .system(size: 18, weight: .bold)
        static let iconSemibold: Font = .system(size: 16, weight: .semibold)
        // Special
        static let timerDisplay: Font = .system(size: 32, weight: .bold, design: .monospaced)
        static let statValue: Font = .system(size: 26, weight: .bold, design: .rounded)
        static let greeting: Font = .system(size: 14, weight: .medium, design: .rounded)
        static let searchField: Font = .system(size: 16)
        static let stepNumber: Font = .system(size: 13, weight: .bold, design: .rounded)
        static let stepIcon: Font = .system(size: 16, weight: .semibold)
        static let statPillLabel: Font = .system(size: 10, weight: .medium, design: .rounded)
        static let statPillValue: Font = .system(size: 14, weight: .bold, design: .rounded)
        static let profileName: Font = .system(size: 24, weight: .bold, design: .rounded)
        static let tagline: Font = .system(size: 15)
        static let inputField: Font = .system(size: 22, weight: .bold, design: .rounded)
    }

    // MARK: - Animations

    /// Named SwiftUI animation presets for consistent motion behaviour across the app.
    struct Anim {
        static let springDefault: SwiftUI.Animation = .spring(response: 0.35)
        static let springNav: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.8)
        static let springBouncy: SwiftUI.Animation = .spring(response: 0.35, dampingFraction: 0.75)
        static let springSmooth: SwiftUI.Animation = .spring(response: 0.45, dampingFraction: 0.85)
        static let springClear: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.85)
        static let springQuick: SwiftUI.Animation = .spring(response: 0.3)
        static let easeQuick: SwiftUI.Animation = .easeInOut(duration: 0.2)
        static let easeDefault: SwiftUI.Animation = .easeInOut
    }

    // MARK: - Common

    /// General-purpose layout constants reused across many screens.
    ///
    /// `bottomSpacerMinLength` reserves space at the bottom of scrollable content
    /// to prevent the last item being obscured by the tab bar.
    struct Common {
        static let stackSpacing: CGFloat = 16
        static let contentSpacing: CGFloat = 16
        static let progressScale: CGFloat = 1.5
        static let placeholderCornerRadius: CGFloat = 6
        static let horizontalPadding: CGFloat = 20
        static let cardCornerRadius: CGFloat = 16
        static let borderWidth: CGFloat = 1
        static let bottomSpacerMinLength: CGFloat = 100
        static let smallSpacing: CGFloat = 4
        static let mediumSpacing: CGFloat = 8
        static let largeSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 14
        static let backButtonSize: CGFloat = 40
        static let neonRadiusDefault: CGFloat = 10
        static let neonRadiusSmall: CGFloat = 8
        static let neonRadiusTiny: CGFloat = 6
        static let neonRadiusMini: CGFloat = 4
        static let dotHeight: CGFloat = 4
        static let dotInactiveWidth: CGFloat = 16
        static let chipHorizontalPadding: CGFloat = 12
        static let chipVerticalPadding: CGFloat = 8
    }

    // MARK: - Onboarding

    /// Layout constants for the first-launch onboarding flow.
    struct Onboarding {
        static let pageSpacing: CGFloat = 32
        static let pageHorizontalPadding: CGFloat = 32
        static let indicatorSpacing: CGFloat = 8
        static let indicatorActiveWidth: CGFloat = 20
        static let indicatorInactiveWidth: CGFloat = 8
        static let indicatorHeight: CGFloat = 8
        static let bottomSpacing: CGFloat = 24
        static let bottomPadding: CGFloat = 48
        static let buttonCornerRadius: CGFloat = 28
        static let buttonVerticalPadding: CGFloat = 16
        static let overlayTopPadding: CGFloat = 24
        static let overlayHorizontalPadding: CGFloat = 20
        static let cameraOverlaySpacing: CGFloat = 12
        static let cameraOverlayPadding: CGFloat = 24
        static let cardSpacing: CGFloat = 24
        static let cardPadding: CGFloat = 24
        static let cardMaxWidth: CGFloat = 360
        static let chipSpacing: CGFloat = 8
        /// Maximum number of detected ingredient chips displayed on the camera scan result overlay.
        static let chipMaxCount: Int = 6
        /// A 1.5-second hold expressed in nanoseconds for `Task.sleep`, keeping the success state
        /// visible before automatically advancing to the next screen.
        static let successDelayNanoseconds: UInt64 = 1_500_000_000
        static let iconSize: CGFloat = 80
        static let stateIconSize: CGFloat = 60
        static let buttonMaxWidth: CGFloat = 320
        static let processingOverlayOpacity: Double = 0.45
    }

    // MARK: - RecipeCell

    /// Layout constants for compact recipe list rows.
    struct RecipeCell {
        static let listRowSpacing: CGFloat = 18
        static let horizontalSpacing: CGFloat = 12
        static let imageSize: CGFloat = 70
        static let imageCornerRadius: CGFloat = 10
        static let contentSpacing: CGFloat = 8
        static let verticalPadding: CGFloat = 4
        static let titleLineLimit: Int = 2
        static let ingredientsSpacing: CGFloat = 6
        /// Number of ingredient chips shown inline before an overflow count badge appears.
        static let maxVisibleIngredients: Int = 3
        static let maxChipWidth: CGFloat = 100
        /// Prefix character for the overflow ingredient count badge, e.g. "+2".
        static let extraIngredientsPrefix = "+"
        static let spacerMinLength: CGFloat = 0
    }

    // MARK: - IngredientChip

    /// Layout constants for ingredient chip views in the ingredient picker grid.
    struct IngredientChip {
        static let lineLimit: Int = 1
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 5
        static let previewCount: Int = 10
    }

    // MARK: - RecipeDetails

    /// Layout constants for the Recipe Details screen.
    ///
    /// Covers the hero image, ingredient list, step cards, floating action buttons,
    /// and the sticky "Start Cooking" CTA.
    struct RecipeDetails {
        static let imageHeight: CGFloat = 250
        static let cardCornerRadius: CGFloat = 10
        static let cardShadowRadius: CGFloat = 0.2
        static let cardShadowOffset: CGFloat = 0.2
        static let additionalInfoCellHeight: CGFloat = 50
        static let additionalInfoSlotsCount: Int = 4
        static let infoTitleSeparator = " "
        static let bulletPrefix = "• "
        static let contentPadding: CGFloat = 24
        static let sectionSpacing: CGFloat = 24
        static let headerSpacing: CGFloat = 8
        static let ratingSpacing: CGFloat = 8
        static let statsSpacing: CGFloat = 0
        static let statsPadding: CGFloat = 4
        static let ingredientsHeaderSpacing: CGFloat = 14
        static let ingredientItemSpacing: CGFloat = 12
        static let ingredientVerticalPadding: CGFloat = 10
        static let ingredientHorizontalPadding: CGFloat = 14
        static let ingredientDividerLeadingPadding: CGFloat = 34
        static let stepsHeaderSpacing: CGFloat = 14
        static let stepsSpacing: CGFloat = 12
        static let stepItemSpacing: CGFloat = 14
        static let stepPadding: CGFloat = 14
        static let stepCornerRadius: CGFloat = 16
        static let stepNumberSize: CGFloat = 28
        static let ingredientDotSize: CGFloat = 8
        static let contentTopCornerRadius: CGFloat = 32
        static let topBarHorizontalPadding: CGFloat = 20
        static let stepTimerHorizontalPadding: CGFloat = 10
        static let stepTimerVerticalPadding: CGFloat = 4
        static let buttonVerticalPadding: CGFloat = 18
        static let buttonCornerRadius: CGFloat = 16
        static let buttonBottomPadding: CGFloat = 16
        static let buttonSpacing: CGFloat = 10
        static let gradientHeight: CGFloat = 100
        static let ingredientDotOpacity: Double = 0.2
        static let matchBadgeOpacity: Double = 0.8
        static let addToListSpacing: CGFloat = 8
        static let addToListPaddingH: CGFloat = 16
        static let addToListPaddingV: CGFloat = 10
        static let addToListCornerRadius: CGFloat = 10
    }

    // MARK: - ShareCard

    /// Fixed-size layout constants for the 4:5 PNG recipe share card.
    struct ShareCard {
        static let width: CGFloat = 1080
        static let height: CGFloat = 1350
        static let renderScale: CGFloat = 1
        static let contentPadding: CGFloat = 72
        static let contentSpacing: CGFloat = 24
        static let metadataSpacing: CGFloat = 16
        static let metadataHorizontalPadding: CGFloat = 26
        static let metadataVerticalPadding: CGFloat = 14
        static let metadataBackgroundOpacity: Double = 0.22
        static let secondaryTextOpacity: Double = 0.82
        static let topOverlayOpacity: Double = 0.08
        static let bottomOverlayOpacity: Double = 0.72
        static let titleLineLimit: Int = 3
        static let titleMinimumScale: CGFloat = 0.72
        static let fallbackCircleOpacity: CGFloat = 0.16
        static let fallbackEmojiSize: CGFloat = 230
        static let fallbackImageScale: CGFloat = 1
        static let fallbackImageSize = CGSize(width: 1080, height: 1350)
        static let titleFont: Font = .system(size: 84, weight: .bold, design: .rounded)
        static let metadataFont: Font = .system(size: 34, weight: .semibold, design: .rounded)
        static let brandFont: Font = .system(size: 28, weight: .bold, design: .rounded)
    }

    // MARK: - Settings

    /// Layout constants for the Settings screen.
    struct Settings {
        static let planInfoSpacing: CGFloat = 4
    }

    // MARK: - V2

    /// Top-level V2 design-system constants not tied to a single component.
    struct V2 {
        static let heroImageHeight: CGFloat = 340
        static let miniCardWidth: CGFloat = 140
        static let miniCardImageHeight: CGFloat = 100
        static let recipeRowImageSize: CGFloat = 92
        static let avatarSize: CGFloat = 80
        static let cookModeTimerSize: CGFloat = 120
        /// Distance (in points) the scrollable content card slides up over the hero image,
        /// creating the layered depth effect on the Recipe Details screen.
        static let contentOverlapOffset: CGFloat = 32
        /// Top padding that positions floating back/bookmark buttons below the status bar.
        static let floatingButtonTopPadding: CGFloat = 56

        /// Layout constants for the `FrostCardModifier`.
        struct FrostCard {
            static let strokeWidth: CGFloat = 0.5
            static let defaultCornerRadius: CGFloat = 20
        }

        /// Tuning constants for the `NeonGlowModifier` two-layer shadow effect.
        ///
        /// The inner layer uses `innerRadiusScale` (40% of the outer radius) for a tight core glow;
        /// the outer layer uses `outerOffsetScale` (25% of the outer radius) as a downward y-offset.
        struct NeonGlow {
            static let defaultRadius: CGFloat = 12
            static let innerOpacity: Double = 0.6
            /// The inner shadow radius as a fraction of the outer radius (0.4 = 40%), producing a tight core glow.
            static let innerRadiusScale: CGFloat = 0.4
            static let outerOpacity: Double = 0.3
            /// The outer shadow y-offset as a fraction of the outer radius (0.25 = 25%), simulating downward cast light.
            static let outerOffsetScale: CGFloat = 0.25
        }

        /// Layout constants for the `SectionLabelModifier`.
        struct SectionLabel {
            static let tracking: CGFloat = 1.5
        }
    }

    // MARK: - RecipeList

    /// Layout constants for the Recipe List "See All" screen.
    struct RecipeList {
        static let stackSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 12
    }

    // MARK: - CookMode

    /// Layout constants for Cook Mode — the full-screen step-by-step cooking flow.
    ///
    /// Covers the progress ring, step navigation buttons, step timer, and the
    /// done/rating feedback overlay.
    struct CookMode {
        static let topBarTopPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 20
        static let closeButtonSize: CGFloat = 40
        static let progressSize: CGFloat = 40
        static let progressLineWidth: CGFloat = 3
        static let dotsSpacing: CGFloat = 6
        static let dotsTopPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 24
        /// Vertical breathing room around the scrollable step content.
        static let stepContentVerticalPadding: CGFloat = 24
        static let timerSpacing: CGFloat = 12
        static let navigationSpacing: CGFloat = 16
        static let navigationButtonSize: CGFloat = 56
        static let bottomPadding: CGFloat = 40
        static let timerLineWidth: CGFloat = 6
        static let timerButtonHorizontalPadding: CGFloat = 24
        static let timerButtonVerticalPadding: CGFloat = 12
        static let timerButtonSpacing: CGFloat = 8
        static let titleInfoSpacing: CGFloat = 2
        static let bgOpacity: Double = 0.3
        static let doneButtonSpacing: CGFloat = 8
        static let feedbackOverlayOpacity: Double = 0.5
        static let feedbackCardSpacing: CGFloat = 24
        static let feedbackCardPadding: CGFloat = 28
        static let feedbackCardHorizontalPadding: CGFloat = 24
        static let feedbackStarSpacing: CGFloat = 12
        static let feedbackStarSize: CGFloat = 36
        static let feedbackButtonSpacing: CGFloat = 12
        static let feedbackButtonHeight: CGFloat = 48
    }

    // MARK: - Discover

    /// Layout constants for the Discover tab (ingredient selection and recipe results states).
    ///
    /// Includes grid dimensions, search bar, mood filter pills, collection cards,
    /// match badge, and the "Find Dinner" CTA button.
    struct Discover {
        static let chefEmoji = "🧑‍🍳"
        /// Solid accent colors and two-stop gradients for each recipe mood filter pill.
        struct Mood {
            static let cozyColor = Color(red: 1.0, green: 0.55, blue: 0.20)
            static let cozyGradient = [cozyColor, Color(red: 0.85, green: 0.30, blue: 0.15)]
            static let freshColor = Color(red: 0.30, green: 0.85, blue: 0.72)
            static let freshGradient = [freshColor, Color(red: 0.15, green: 0.65, blue: 0.55)]
            static let boldColor = Color(red: 0.95, green: 0.35, blue: 0.50)
            static let boldGradient = [boldColor, Color(red: 0.75, green: 0.20, blue: 0.40)]
            static let comfortColor = Color(red: 0.65, green: 0.50, blue: 0.95)
            static let comfortGradient = [comfortColor, Color(red: 0.45, green: 0.30, blue: 0.80)]
            static let quickColor = Color(red: 0.35, green: 0.65, blue: 1.0)
            static let quickGradient = [quickColor, Color(red: 0.20, green: 0.45, blue: 0.85)]
        }

        static let horizontalPadding: CGFloat = 20
        static let headerTopPadding: CGFloat = 8
        static let searchBarHorizontalPadding: CGFloat = 16
        static let searchBarVerticalPadding: CGFloat = 14
        static let sectionSpacing: CGFloat = 24
        static let gridSpacing: CGFloat = 12
        static let recipeImageHeight: CGFloat = 240
        static let recipeCardCornerRadius: CGFloat = 24
        static let bottomSpacerMinLength: CGFloat = 100
        static let gridItemSpacing: CGFloat = 10
        static let gridColumnCount: Int = 4
        static let headerSpacing: CGFloat = 6
        static let searchBarSpacing: CGFloat = 12
        static let searchBarCornerRadius: CGFloat = 16
        static let sectionContentSpacing: CGFloat = 12
        static let categoryChipSpacing: CGFloat = 8
        static let ingredientGridHeaderSpacing: CGFloat = 14
        static let loadingPadding: CGFloat = 40
        static let resultsHeaderSpacing: CGFloat = 2
        static let ingredientStripSpacing: CGFloat = 10
        static let addButtonSize: CGFloat = 34
        static let moodPillSpacing: CGFloat = 10
        static let bestMatchSpacing: CGFloat = 12
        static let moreRecipesSpacing: CGFloat = 14
        static let featuredInfoSpacing: CGFloat = 6
        static let matchBadgeSpacing: CGFloat = 4
        static let matchBadgePaddingH: CGFloat = 10
        static let matchBadgePaddingV: CGFloat = 5
        static let matchInfoButtonSize: CGFloat = 16
        static let matchPopoverSpacing: CGFloat = 6
        static let matchPopoverPadding: CGFloat = 12
        static let matchPopoverWidth: CGFloat = 220
        static let featuredInfoPadding: CGFloat = 18
        static let featuredLabelSpacing: CGFloat = 12
        static let gradientOpacityTop: Double = 0.8
        static let gradientOpacityMid: Double = 0.3
        static let whiteOpacity085: Double = 0.85
        static let findButtonHeight: CGFloat = 56
        static let findButtonCornerRadius: CGFloat = 28 // Pill shape for 56 height
        static let findButtonBottomPadding: CGFloat = 16
        static let cameraBadgeFontSize: CGFloat = 8
        static let cameraBadgePaddingH: CGFloat = 3
        static let cameraBadgePaddingV: CGFloat = 1
        static let cameraBadgeOffsetX: CGFloat = 8
        static let cameraBadgeOffsetY: CGFloat = -6
        static let useItAllPaddingH: CGFloat = 14
        static let useItAllPaddingV: CGFloat = 8
        static let chefEmojiSize: CGFloat = 20
        static let suggestionPopupCornerRadius: CGFloat = 14
        static let suggestionPopupShadowRadius: CGFloat = 10
        static let suggestionPopupShadowY: CGFloat = 4
        static let suggestionPopupShadowOpacity: Double = 0.10
        static let suggestionRowPaddingH: CGFloat = 14
        static let suggestionRowPaddingV: CGFloat = 11
        static let suggestionPopupTopGap: CGFloat = 4
        static let suggestionPopupItemLimit: Int = 6
        /// Maximum number of recipes fetched for ingredient-free browse searches.
        static let browseRecipeLimit: Int = 100

        /// Dimensions and gradient colors for the "This Week's Collections" card strip on the Discover screen.
        struct Collection {
            static let cardWidth: CGFloat = 140
            static let cardHeight: CGFloat = 100
            static let emojiFontSize: CGFloat = 30
            static let titleOpacity: Double = 1.0
            static let subtitleOpacity: Double = 0.8
            static let cornerRadius: CGFloat = 20
            // Gradient colour pairs for collection cards
            static let mintStart = Color(red: 0.18, green: 0.62, blue: 0.53)
            static let mintEnd = Color(red: 0.25, green: 0.82, blue: 0.70)
            static let skyStart = Color(red: 0.25, green: 0.55, blue: 0.96)
            static let skyEnd = Color(red: 0.40, green: 0.72, blue: 1.0)
            static let roseStart = Color(red: 0.85, green: 0.38, blue: 0.47)
            static let roseEnd = Color(red: 1.0, green: 0.56, blue: 0.62)
            static let goldStart = Color(red: 0.88, green: 0.62, blue: 0.12)
            static let goldEnd = Color(red: 1.0, green: 0.78, blue: 0.30)
            static let lavenderStart = Color(red: 0.50, green: 0.42, blue: 0.85)
            static let lavenderEnd = Color(red: 0.68, green: 0.58, blue: 1.0)
            static let freshStart = Color(red: 0.30, green: 0.72, blue: 0.48)
            static let freshEnd = Color(red: 0.50, green: 0.90, blue: 0.62)
        }

        /// Returns the solid accent color for the given recipe mood.
        /// - Parameter mood: The mood to resolve a color for.
        /// - Returns: A `Color` matching the mood's visual identity.
        static func moodColor(for mood: RecipeMood) -> Color {
            switch mood {
            case .cozy:
                return Mood.cozyColor
            case .fresh:
                return Mood.freshColor
            case .bold:
                return Mood.boldColor
            case .comfort:
                return Mood.comfortColor
            case .quick:
                return Mood.quickColor
            }
        }

        /// Returns a two-stop gradient color array for the given recipe mood.
        /// - Parameter mood: The mood to resolve a gradient for.
        /// - Returns: An array of two `Color` values (start, end) for the mood's gradient.
        static func moodGradient(for mood: RecipeMood) -> [Color] {
            switch mood {
            case .cozy:
                return Mood.cozyGradient
            case .fresh:
                return Mood.freshGradient
            case .bold:
                return Mood.boldGradient
            case .comfort:
                return Mood.comfortGradient
            case .quick:
                return Mood.quickGradient
            }
        }
    }

    // MARK: - Components (V2Components)

    /// Layout constants for reusable shared components in `Views/Shared/`.
    ///
    /// Covers `RecipeImage`, `MiniRecipeCard`, `RecipeRow` and its sub-components,
    /// category chips, ingredient bubbles, selected chips, mood pills, star ratings,
    /// stat pills, and the add/create recipe cards.
    struct Components {
        // RecipeImage
        static let recipeImageDefaultHeight: CGFloat = 200
        static let emojiScaleFactor: CGFloat = 0.3
        static let emojiShadowOpacity: Double = 0.25
        static let emojiShadowRadius: CGFloat = 12
        static let emojiShadowY: CGFloat = 6
        static let gradientPairCount: Int = 6
        static let gradientOpacity: Double = 0.85
        // MiniRecipeCard
        static let miniCardContentSpacing: CGFloat = 4
        static let miniCardPaddingH: CGFloat = 10
        static let miniCardPaddingV: CGFloat = 8
        static let miniCardIconSpacing: CGFloat = 4
        static let miniCardTitleLineLimit: Int = 1
        // RecipeRow
        /// Layout constants for the full-width `RecipeRow` card component.
        struct RecipeRow {
            static let spacing: CGFloat = 14
            static let contentSpacing: CGFloat = 8
            static let infoSpacing: CGFloat = 8
            static let padding: CGFloat = 12
            static let titleLineLimit: Int = 2
            static let taglineLineLimit: Int = 2

            /// Shadow and background-layer constants for the `RecipeRow` card container.
            struct Card {
                static let accentShadowOpacity: Double = 0.10
                static let shadowRadius: CGFloat = 18
                static let shadowY: CGFloat = 10
                static let shadowOpacity: Double = 0.10
                static let secondaryShadowRadius: CGFloat = 12
                static let secondaryShadowY: CGFloat = 6
                static let backgroundMidOpacity: Double = 0.98
                static let backgroundBottomOpacity: Double = 0.92
                static let borderOpacity: Double = 0.9
            }

            /// Visual-processing and shadow constants for the recipe thumbnail image inside `RecipeRow`.
            ///
            /// Slight saturation and contrast boosts (`saturation`, `contrast`) enhance food photography.
            /// Tinted overlays (`overlaySkyOpacity`, `overlayAccentOpacity`) add warmth without washing out colors.
            struct Thumbnail {
                static let inset: CGFloat = 3
                static let saturation: Double = 1.04
                static let contrast: Double = 1.03
                static let overlaySkyOpacity: Double = 0.08
                static let overlayAccentOpacity: Double = 0.16
                static let borderOpacity: Double = 0.65
                static let accentShadowOpacity: Double = 0.16
                static let shadowRadius: CGFloat = 16
                static let accentShadowY: CGFloat = 6
                static let roseShadowOpacity: Double = 0.08
                static let roseShadowRadius: CGFloat = 12
                static let roseShadowY: CGFloat = 8
                static let shadowOpacity: Double = 0.14
                static let secondaryShadowRadius: CGFloat = 8
                static let secondaryShadowY: CGFloat = 4
            }

            /// Layout constants for the floating bookmark button overlaid on `RecipeRow`.
            struct Bookmark {
                static let size: CGFloat = 34
                static let backgroundOpacity: Double = 0.72
            }

            /// Layout constants for the metadata pill (rating, time) overlaid on `RecipeRow`.
            struct Meta {
                static let paddingH: CGFloat = 8
                static let paddingV: CGFloat = 5
                static let backgroundOpacity: Double = 0.12
                static let ratingSpacing: CGFloat = 4
            }
        }
        // CategoryChip
        static let categoryChipSpacing: CGFloat = 5
        static let categoryChipPaddingH: CGFloat = 14
        static let categoryChipPaddingV: CGFloat = 9
        // IngredientBubble
        static let bubbleSpacing: CGFloat = 6
        static let bubbleSize: CGFloat = 60
        static let bubbleSelectedBorder: CGFloat = 2
        static let bubbleEmojiSize: CGFloat = 26
        static let bubbleSelectedScale: CGFloat = 1.08
        static let alwaysHaveBadgePaddingH: CGFloat = 7
        static let alwaysHaveBadgePaddingV: CGFloat = 3
        static let pantryToggleSize: CGFloat = 22
        static let pantryToggleHitSize: CGFloat = 44
        static let pantryToggleIconSize: CGFloat = 10
        static let pantryToggleOffset: CGFloat = 2
        // SelectedChip
        static let selectedChipSpacing: CGFloat = 5
        static let selectedChipPaddingH: CGFloat = 12
        static let selectedChipPaddingV: CGFloat = 8
        // MoodPill
        static let moodPillSpacing: CGFloat = 6
        static let moodPillPaddingH: CGFloat = 16
        static let moodPillPaddingV: CGFloat = 10
        static let moodPillUnselectedOpacity: Double = 0.12
        static let moodPillBorderOpacity: Double = 0.2
        static let moodPillGlowRadius: CGFloat = 6
        // StarRating
        static let starSpacing: CGFloat = 2
        // StatPill
        static let statPillSpacing: CGFloat = 6
        static let statPillPadding: CGFloat = 14
        // AddYourOwnCard
        static let addCardSpacing: CGFloat = 8
        static let addCardHeight: CGFloat = 148
        static let addCardIconSpacing: CGFloat = 6
        static let addCardDashWidth: CGFloat = 1.5
        static let addCardDashPattern: [CGFloat] = [6, 4]
        // CreateRecipeCard
        static let createCardSpacing: CGFloat = 8
        static let createCardTitleSpacing: CGFloat = 2
        // UserMiniRecipeCard
        static let userCardIconSize: CGFloat = 18
        static let userCardOffset: CGFloat = 6
    }

    // MARK: - Journey

    /// Layout constants for the My Kitchen (Journey) screen.
    ///
    /// Covers the stats grid, weekly activity dots, achievement badges,
    /// recent activity feed, shopping list shortcut card, and the account sign-in card.
    struct Journey {
        static let sectionSpacing: CGFloat = 24
        static let horizontalPadding: CGFloat = 20
        static let compactSectionSpacing: CGFloat = 18
        static let utilityCardSpacing: CGFloat = 14
        static let contentTopPadding: CGFloat = 8
        static let statsGridSpacing: CGFloat = 12
        static let statItemSpacing: CGFloat = 10
        static let statItemPadding: CGFloat = 18
        static let statIconSize: CGFloat = 20
        static let myRecipesSpacing: CGFloat = 12
        static let weeklySpacing: CGFloat = 14
        static let dayCircleSize: CGFloat = 36
        static let dayTodayCircleSize: CGFloat = 42
        static let dayCircleSpacing: CGFloat = 8
        static let weeklyPadding: CGFloat = 16
        static let dayTodayBorderWidth: CGFloat = 2
        static let achievementSpacing: CGFloat = 14
        static let achievementRowSpacing: CGFloat = 14
        static let achievementIconSize: CGFloat = 44
        static let achievementPadding: CGFloat = 14
        static let achievementIconOpacity: Double = 0.2
        static let achievementProgressHeight: CGFloat = 4
        static let achievementBadgeSize: CGFloat = 56
        static let achievementBadgeEmojiSize: CGFloat = 22
        static let achievementBadgeWidth: CGFloat = 64
        static let achievementBadgeSpacing: CGFloat = 12
        static let achievementBadgeHorizontalPadding: CGFloat = 4
        static let achievementBadgeLabelSpacing: CGFloat = 6
        static let achievementBadgeStrokeOpacity: Double = 0.4
        static let achievementBadgeLockedOpacity: Double = 0.4
        static let achievementCompactSpacing: CGFloat = 12
        static let achievementSummarySpacing: CGFloat = 8
        static let achievementCompactPadding: CGFloat = 16
        static let achievementToggleSpacing: CGFloat = 8
        static let recentActivitySpacing: CGFloat = 14
        static let activityRowSpacing: CGFloat = 12
        static let activityIconSize: CGFloat = 50
        static let activityIconCornerRadius: CGFloat = 12
        static let activityTextSpacing: CGFloat = 3
        static let activityDividerLeading: CGFloat = 76
        static let activityVerticalPadding: CGFloat = 12
        static let activityHorizontalPadding: CGFloat = 14
        static let shortcutIconSize: CGFloat = 52
        static let shortcutContentSpacing: CGFloat = 14
        static let shortcutTextSpacing: CGFloat = 4
        static let shortcutVerticalPadding: CGFloat = 16
        static let shortcutHorizontalPadding: CGFloat = 16
        static let shortcutButtonPaddingH: CGFloat = 14
        static let shortcutButtonPaddingV: CGFloat = 10
        static let shortcutButtonSpacing: CGFloat = 8
        static let accountCardPadding: CGFloat = 16
        static let accountCardContentSpacing: CGFloat = 14
        static let accountCardTextSpacing: CGFloat = 2
        static let accountCardButtonSpacing: CGFloat = 6
        static let accountCardIconSize: CGFloat = 28
    }

    // MARK: - CreateRecipe

    /// Layout constants for the five-step Create Recipe wizard.
    struct CreateRecipe {
        static let minServings = 1
        static let maxServings = 12
        /// Available cook-time presets (in minutes) displayed as selectable chips in the Details step.
        static let cookTimeOptions = [5, 10, 15, 20, 30, 45, 60, 90]
        /// Allowed line-count range for step text input fields — grows from 3 to 6 lines before scrolling.
        static let stepTextLineLimit = 3...6
        static let horizontalPadding: CGFloat = 24
        static let topPadding: CGFloat = 24
        static let bottomScrollPadding: CGFloat = 100
        static let headerHorizontalPadding: CGFloat = 20
        static let headerTopPadding: CGFloat = 16
        static let headerButtonSize: CGFloat = 36
        static let dotsPadding: CGFloat = 24
        static let dotsTopPadding: CGFloat = 12
        static let sectionSpacing: CGFloat = 24
        static let fieldSpacing: CGFloat = 8
        static let photoHeight: CGFloat = 160
        static let photoCornerRadius: CGFloat = 24
        static let inputPadding: CGFloat = 16
        static let inputCornerRadius: CGFloat = 16
        static let emojiGridSpacing: CGFloat = 10
        static let emojiGridColumns: Int = 6
        static let emojiSize: CGFloat = 48
        static let emojiSelectedScale: CGFloat = 1.1
        static let ingredientSpacing: CGFloat = 16
        static let ingredientRowSpacing: CGFloat = 10
        static let ingredientItemSpacing: CGFloat = 10
        static let ingredientInputPadding: CGFloat = 14
        static let ingredientInputCornerRadius: CGFloat = 12
        static let addButtonCornerRadius: CGFloat = 12
        static let addButtonVerticalPadding: CGFloat = 12
        static let addButtonSpacing: CGFloat = 8
        static let stepsSpacing: CGFloat = 16
        static let stepsRowSpacing: CGFloat = 12
        static let stepRowItemSpacing: CGFloat = 10
        static let stepNumberTopPadding: CGFloat = 10
        static let stepDeleteTopPadding: CGFloat = 14
        static let detailsSpacing: CGFloat = 28
        static let detailItemSpacing: CGFloat = 10
        static let cookTimeChipSpacing: CGFloat = 8
        static let cookTimeChipPaddingH: CGFloat = 18
        static let cookTimeChipPaddingV: CGFloat = 10
        static let servingsSpacing: CGFloat = 20
        static let servingsButtonSize: CGFloat = 44
        static let servingsValueWidth: CGFloat = 50
        static let servingsPadding: CGFloat = 16
        static let difficultySpacing: CGFloat = 10
        static let difficultyPaddingV: CGFloat = 14
        static let reviewSpacing: CGFloat = 20
        static let reviewImageHeight: CGFloat = 180
        static let reviewContentSpacing: CGFloat = 12
        static let reviewContentPadding: CGFloat = 18
        static let reviewStatsSpacing: CGFloat = 16
        static let bottomGradientHeight: CGFloat = 30
        static let bottomButtonSpacing: CGFloat = 8
        static let bottomButtonVerticalPadding: CGFloat = 18
        static let bottomButtonCornerRadius: CGFloat = 16
        static let bottomPaddingH: CGFloat = 24
        static let bottomPaddingV: CGFloat = 16
        static let reviewEmojiSize: CGFloat = 56
        static let photoEmojiSize: CGFloat = 64
        static let disabledOpacity: Double = 0.5
        static let opacityHalf: Double = 0.5
        static let opacityLight: Double = 0.3
        static let opacitySubtle: Double = 0.25
        static let opacityFaint: Double = 0.12
    }

    // MARK: - RecipeBadge

    /// Thresholds and layout constants for recipe badge labels ("Quick", "Easy", "Beginner").
    struct RecipeBadge {
        static let spacing: CGFloat = 4
        /// Vertical gap between badge rows when they wrap in `WrappingFlowLayout`.
        static let rowSpacing: CGFloat = 4
        static let paddingH: CGFloat = 8
        static let paddingV: CGFloat = 4
        static let backgroundOpacity: Double = 0.12
        /// Recipes at or under this cook time (in minutes) are awarded the "Quick" badge.
        static let quickThresholdMinutes: Int = 20
        /// Recipes with this many ingredients or fewer are awarded the "Beginner" badge.
        static let beginnerMaxIngredients: Int = 5
    }

    // MARK: - ShoppingList

    /// Layout constants for the Shopping List sheet.
    struct ShoppingList {
        static let horizontalPadding: CGFloat = 20
        static let checkboxSize: CGFloat = 22
        static let checkboxSpacing: CGFloat = 12
        static let rowVerticalPadding: CGFloat = 12
        static let emptyStateSpacing: CGFloat = 20
        static let emptyIconSize: CGFloat = 60
    }

    // MARK: - Upgrade

    /// Layout constants for the Upgrade / subscription paywall screen.
    struct Upgrade {
        static let headerSpacing: CGFloat = 24
        static let contentSpacing: CGFloat = 16
        static let featureSpacing: CGFloat = 8
        static let headerIconSize: CGFloat = 50
        static let headerInnerSpacing: CGFloat = 12
        static let planCardSpacing: CGFloat = 4
        static let currentBadgePaddingH: CGFloat = 8
        static let currentBadgePaddingV: CGFloat = 4
        static let currentBadgeCornerRadius: CGFloat = 6
        static let currentBadgeBgOpacity: Double = 0.15
        static let promotedBadgePaddingH: CGFloat = 10
        static let promotedBadgePaddingV: CGFloat = 5
        static let promotedBadgeCornerRadius: CGFloat = 8
        static let promotedBorderWidth: CGFloat = 1.5
        static let savingsPaddingH: CGFloat = 10
        static let savingsPaddingV: CGFloat = 6
        static let savingsCornerRadius: CGFloat = 8
        static let subscribeCornerRadius: CGFloat = 12
        static let cardCornerRadius: CGFloat = 16
        static let shadowOpacity: Double = 0.1
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 2
    }

    /// Layout constants for Sign in with Apple and account-related UI elements.
    struct Auth {
        static let signInButtonHeight: CGFloat = 50
        static let signInButtonCornerRadius: CGFloat = 12
        static let accountIconSize: CGFloat = 40
    }

    // MARK: - ImageProcessing

    /// Tuning constants for image preprocessing before remote AI ingredient detection.
    ///
    /// Camera captures are full-resolution (~12MP). The remote vision model internally
    /// downscales and tiles images anyway, so sending native frames only inflates the
    /// base64 payload and upload latency without improving detection. Downscaling the long
    /// edge to `detectionMaxDimension` preserves enough detail for fine-grained items
    /// (herbs, labels, similar produce) while cutting payload size by roughly an order of
    /// magnitude. Color is intentionally preserved — it is a primary signal for food
    /// recognition. The slightly lower `detectionJPEGQuality` is acceptable because the
    /// resize already removes most redundant detail.
    struct ImageProcessing {
        // `nonisolated` so the off-main (`@concurrent`) image encode in
        // `AIIngredientDetectionAdapter` can read these constants without hopping to the main actor.
        /// Maximum length (in pixels) of the longer image edge sent for AI detection.
        /// The shorter edge scales proportionally to preserve aspect ratio.
        nonisolated static let detectionMaxDimension: CGFloat = 1280
        /// JPEG compression quality (0...1) applied after downscaling for AI detection.
        nonisolated static let detectionJPEGQuality: CGFloat = 0.7
    }
}
