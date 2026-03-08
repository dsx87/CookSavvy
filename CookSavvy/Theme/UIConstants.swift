import SwiftUI

struct UI {

    // MARK: - Fonts

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

    // MARK: - RecipeCell

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

    // MARK: - IngredientChip

    struct IngredientChip {
        static let lineLimit: Int = 1
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 5
        static let previewCount: Int = 10
    }

    // MARK: - RecipeDetails

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
    }

    // MARK: - Settings

    struct Settings {
        static let planInfoSpacing: CGFloat = 4
    }

    // MARK: - SourceBadge

    struct SourceBadge {
        static let iconSize: CGFloat = 12
        static let width: CGFloat = 40
        static let height: CGFloat = 32
        static let borderOpacity: Double = 0.9
        static let tintOpacity: Double = 0.22
        static let popoverSpacing: CGFloat = 8
        static let popoverPadding: CGFloat = 14
        static let popoverWidth: CGFloat = 220
    }

    // MARK: - DiskImage

    struct DiskImage {
        static let defaultPrefix = "Food Images/Food Images/"
        static let defaultExtension = ".jpg"
    }

    // MARK: - V2

    struct V2 {
        static let heroImageHeight: CGFloat = 340
        static let miniCardWidth: CGFloat = 140
        static let miniCardImageHeight: CGFloat = 100
        static let recipeRowImageSize: CGFloat = 92
        static let avatarSize: CGFloat = 80
        static let cookModeTimerSize: CGFloat = 120
        static let contentOverlapOffset: CGFloat = 32
        static let floatingButtonTopPadding: CGFloat = 56

        struct FrostCard {
            static let strokeWidth: CGFloat = 0.5
            static let defaultCornerRadius: CGFloat = 20
        }

        struct NeonGlow {
            static let defaultRadius: CGFloat = 12
            static let innerOpacity: Double = 0.6
            static let innerRadiusScale: CGFloat = 0.4
            static let outerOpacity: Double = 0.3
            static let outerOffsetScale: CGFloat = 0.25
        }

        struct SectionLabel {
            static let tracking: CGFloat = 1.5
        }
    }

    // MARK: - RecipeList

    struct RecipeList {
        static let stackSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 12
    }

    // MARK: - CookMode

    struct CookMode {
        static let topBarTopPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 20
        static let closeButtonSize: CGFloat = 40
        static let progressSize: CGFloat = 40
        static let progressLineWidth: CGFloat = 3
        static let dotsSpacing: CGFloat = 6
        static let dotsTopPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 24
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
    }

    // MARK: - Discover

    struct Discover {
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

    struct Components {
        // RecipeImage
        static let recipeImageDefaultHeight: CGFloat = 200
        static let emojiScaleFactor: CGFloat = 0.3
        static let emojiShadowOpacity: Double = 0.25
        static let emojiShadowRadius: CGFloat = 12
        static let emojiShadowY: CGFloat = 6
        // MiniRecipeCard
        static let miniCardContentSpacing: CGFloat = 4
        static let miniCardPaddingH: CGFloat = 10
        static let miniCardPaddingV: CGFloat = 8
        static let miniCardIconSpacing: CGFloat = 4
        static let miniCardTitleLineLimit: Int = 1
        // RecipeRow
        struct RecipeRow {
            static let spacing: CGFloat = 14
            static let contentSpacing: CGFloat = 8
            static let infoSpacing: CGFloat = 8
            static let padding: CGFloat = 12
            static let titleLineLimit: Int = 2
            static let taglineLineLimit: Int = 2

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

            struct Bookmark {
                static let size: CGFloat = 34
                static let backgroundOpacity: Double = 0.72
            }

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

    struct Journey {
        static let sectionSpacing: CGFloat = 24
        static let horizontalPadding: CGFloat = 20
        static let profileSpacing: CGFloat = 16
        static let profileTopPadding: CGFloat = 8
        static let profileNameSpacing: CGFloat = 4
        static let levelSpacing: CGFloat = 8
        static let levelPaddingH: CGFloat = 16
        static let levelPaddingV: CGFloat = 8
        static let levelBadgeOpacity: Double = 0.12
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
        static let recentActivitySpacing: CGFloat = 14
        static let activityRowSpacing: CGFloat = 12
        static let activityIconSize: CGFloat = 50
        static let activityIconCornerRadius: CGFloat = 12
        static let activityTextSpacing: CGFloat = 3
        static let activityDividerLeading: CGFloat = 76
        static let activityVerticalPadding: CGFloat = 12
        static let activityHorizontalPadding: CGFloat = 14
        static let emojiSize: CGFloat = 40
    }

    // MARK: - CreateRecipe

    struct CreateRecipe {
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

    // MARK: - Upgrade

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
        static let subscribeCornerRadius: CGFloat = 12
        static let cardCornerRadius: CGFloat = 16
        static let shadowOpacity: Double = 0.1
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 2
    }
}
