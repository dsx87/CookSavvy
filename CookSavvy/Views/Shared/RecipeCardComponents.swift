import SwiftUI

private enum RecipeImageStyle {
    static let placeholderImageName = "recipe_placeholder"
    static let defaultEmoji = "🍽️"

    private static let keywordEmojiMap: [(keyword: String, emoji: String)] = [
        ("chicken", "🍗"),
        ("pasta", "🍝"),
        ("salad", "🥗"),
        ("soup", "🍲"),
        ("beef", "🥩"),
        ("fish", "🐟"),
        ("cake", "🍰"),
    ]

    static func emoji(for recipe: Recipe) -> String {
        if let emoji = recipe.emoji { return emoji }
        let title = recipe.title.lowercased()
        for (keyword, emoji) in keywordEmojiMap {
            if title.contains(keyword) { return emoji }
        }
        return defaultEmoji
    }
}

struct RecipeImage: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe
    var height: CGFloat = UI.Components.recipeImageDefaultHeight
    var contentMode: ContentMode = .fill

    var body: some View {
        ZStack {
            if recipe.image.isEmpty || recipe.image == RecipeImageStyle.placeholderImageName {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(RecipeImageStyle.emoji(for: recipe))
                    .font(.system(size: height * UI.Components.emojiScaleFactor))
                    .shadow(color: .black.opacity(UI.Components.emojiShadowOpacity), radius: UI.Components.emojiShadowRadius, y: UI.Components.emojiShadowY)
            } else {
                AsyncImageDisk(imageName: recipe.image, contentMode: contentMode) {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Text(RecipeImageStyle.emoji(for: recipe))
                            .font(.system(size: height * UI.Components.emojiScaleFactor))
                            .shadow(color: .black.opacity(UI.Components.emojiShadowOpacity), radius: UI.Components.emojiShadowRadius, y: UI.Components.emojiShadowY)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .clipped()
    }

    private var gradientColors: [Color] {
        let hash = recipe.title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let index = abs(hash) % UI.Components.gradientPairCount
        let op = UI.Components.gradientOpacity
        let pairs: [[Color]] = [
            [theme.accent.opacity(op), theme.rose.opacity(op)],
            [theme.mint.opacity(op), theme.sky.opacity(op)],
            [theme.lavender.opacity(op), theme.rose.opacity(op)],
            [theme.gold.opacity(op), theme.accent.opacity(op)],
            [theme.sky.opacity(op), theme.mint.opacity(op)],
            [theme.rose.opacity(op), theme.lavender.opacity(op)],
        ]
        return pairs[index]
    }
}

struct MiniRecipeCard: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeImage(recipe: recipe, height: UI.V2.miniCardImageHeight, contentMode: .fill)
                .frame(width: UI.V2.miniCardWidth)

            VStack(alignment: .leading, spacing: UI.Components.miniCardContentSpacing) {
                Text(recipe.title)
                    .font(UI.Fonts.captionBold)
                    .foregroundStyle(theme.text1)
                    .lineLimit(UI.Components.miniCardTitleLineLimit)

                HStack(spacing: UI.Components.miniCardIconSpacing) {
                    Image(systemName: Icons.Discover.clock)
                        .font(UI.Fonts.micro)
                    Text(cookTimeText)
                        .font(UI.Fonts.tinyCaption)
                }
                .foregroundStyle(theme.text3)
            }
            .padding(.horizontal, UI.Components.miniCardPaddingH)
            .padding(.vertical, UI.Components.miniCardPaddingV)
        }
        .frame(width: UI.V2.miniCardWidth)
        .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cookTimeText.isEmpty ? recipe.title : "\(recipe.title), \(cookTimeText)")
    }

    private var cookTimeText: String {
        for info in recipe.additionalInfo.infos {
            if case .time(let t) = info { return t }
        }
        return ""
    }
}

struct RecipeRow: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe
    var isSaved: Bool = false

    var body: some View {
        HStack(spacing: UI.Components.RecipeRow.spacing) {
            rowThumbnail
            recipeContent
            bookmarkBadge
        }
        .padding(UI.Components.RecipeRow.padding)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))
        .shadow(
            color: theme.accent.opacity(UI.Components.RecipeRow.Card.accentShadowOpacity * theme.shadowStrength),
            radius: UI.Components.RecipeRow.Card.shadowRadius,
            x: 0,
            y: UI.Components.RecipeRow.Card.shadowY
        )
        .shadow(
            color: .black.opacity(UI.Components.RecipeRow.Card.shadowOpacity * theme.shadowStrength),
            radius: UI.Components.RecipeRow.Card.secondaryShadowRadius,
            x: 0,
            y: UI.Components.RecipeRow.Card.secondaryShadowY
        )
    }

    private var recipeContent: some View {
        VStack(alignment: .leading, spacing: UI.Components.RecipeRow.contentSpacing) {
            Text(recipe.title)
                .font(UI.Fonts.recipeRowTitle)
                .foregroundStyle(theme.text1)
                .lineLimit(UI.Components.RecipeRow.titleLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let tagline = recipe.tagline {
                Text(tagline)
                    .font(UI.Fonts.caption)
                    .foregroundStyle(theme.text2)
                    .lineLimit(UI.Components.RecipeRow.taglineLineLimit)
            }

            if let reason = recipe.matchReason {
                Label(reason, systemImage: "lightbulb.fill")
                    .font(UI.Fonts.tinyCaption)
                    .foregroundStyle(theme.mint)
                    .padding(.horizontal, UI.Components.RecipeRow.Meta.paddingH)
                    .padding(.vertical, UI.Components.RecipeRow.Meta.paddingV)
                    .background(theme.mintSoft, in: Capsule())
            }

            if let missing = recipe.missingIngredients {
                if missing.isEmpty {
                    Label(Strings.Discover.haveAll, systemImage: "checkmark.circle.fill")
                        .font(UI.Fonts.tinyCaption)
                        .foregroundStyle(theme.mint)
                        .padding(.horizontal, UI.Components.RecipeRow.Meta.paddingH)
                        .padding(.vertical, UI.Components.RecipeRow.Meta.paddingV)
                        .background(theme.mintSoft, in: Capsule())
                } else {
                    Label(String(format: Strings.Discover.missingCount, missing.count), systemImage: "cart.badge.plus")
                        .font(UI.Fonts.tinyCaption)
                        .foregroundStyle(theme.rose)
                        .padding(.horizontal, UI.Components.RecipeRow.Meta.paddingH)
                        .padding(.vertical, UI.Components.RecipeRow.Meta.paddingV)
                        .background(theme.roseSoft, in: Capsule())
                }
            }

            metaInfoRow

            RecipeBadges(recipe: recipe)

            Spacer(minLength: 0)
        }
    }

    private var metaInfoRow: some View {
        HStack(spacing: UI.Components.RecipeRow.infoSpacing) {
            if let time = cookTimeText {
                rowMetaLabel(time, systemImage: Icons.Discover.clock, tint: theme.accent)
            }
            if let calories = caloriesText {
                rowMetaLabel(calories, systemImage: Icons.Discover.flame, tint: theme.rose)
            }
            if let rating = recipe.apiRating ?? recipe.userRating {
                rowRating(rating)
            }
        }
        .font(UI.Fonts.tinyCaptionMedium)
    }

    private var cookTimeText: String? {
        for info in recipe.additionalInfo.infos {
            if case .time(let t) = info { return t }
        }
        return nil
    }

    private var caloriesText: String? {
        for info in recipe.additionalInfo.infos {
            if case .calories(let c) = info { return "\(c) cal" }
        }
        return nil
    }

    private var rowThumbnail: some View {
        RecipeRowThumbnailView(recipe: recipe)
    }

    private var bookmarkBadge: some View {
        Image(systemName: isSaved ? Icons.Discover.bookmarkFill : Icons.Discover.bookmark)
            .font(UI.Fonts.iconSemibold)
            .foregroundStyle(isSaved ? theme.accent : theme.text3)
            .frame(width: UI.Components.RecipeRow.Bookmark.size, height: UI.Components.RecipeRow.Bookmark.size)
            .background(theme.surface.opacity(UI.Components.RecipeRow.Bookmark.backgroundOpacity), in: Circle())
            .overlay {
                Circle()
                    .stroke(theme.divider, lineWidth: UI.Common.borderWidth)
            }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        theme.card,
                        theme.card.opacity(UI.Components.RecipeRow.Card.backgroundMidOpacity),
                        theme.surface.opacity(UI.Components.RecipeRow.Card.backgroundBottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        theme.frostStrokeTop.opacity(UI.Components.RecipeRow.Card.borderOpacity),
                        theme.frostStrokeBottom.opacity(UI.Components.RecipeRow.Card.borderOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: UI.V2.FrostCard.strokeWidth
            )
    }

    private func rowMetaLabel(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(UI.Fonts.tinyCaptionMedium)
            .foregroundStyle(theme.text2)
            .padding(.horizontal, UI.Components.RecipeRow.Meta.paddingH)
            .padding(.vertical, UI.Components.RecipeRow.Meta.paddingV)
            .background(tint.opacity(UI.Components.RecipeRow.Meta.backgroundOpacity), in: Capsule())
    }

    private func rowRating(_ rating: Double) -> some View {
        HStack(spacing: UI.Components.RecipeRow.Meta.ratingSpacing) {
            StarRating(rating: rating)
            Text(String(format: "%.1f", rating))
                .font(UI.Fonts.tinyCaptionMedium)
                .foregroundStyle(theme.text2)
        }
        .padding(.horizontal, UI.Components.RecipeRow.Meta.paddingH)
        .padding(.vertical, UI.Components.RecipeRow.Meta.paddingV)
        .background(theme.gold.opacity(UI.Components.RecipeRow.Meta.backgroundOpacity), in: Capsule())
    }
}

private struct RecipeRowThumbnailView: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe

    private let shape = RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous)

    var body: some View {
        ZStack {
            shape.fill(theme.surfaceLight)
            styledImage
        }
        .frame(width: UI.V2.recipeRowImageSize, height: UI.V2.recipeRowImageSize)
        .background(thumbnailBackground)
        .shadow(
            color: theme.accent.opacity(UI.Components.RecipeRow.Thumbnail.accentShadowOpacity * theme.shadowStrength),
            radius: UI.Components.RecipeRow.Thumbnail.shadowRadius,
            x: 0, y: UI.Components.RecipeRow.Thumbnail.accentShadowY
        )
        .shadow(
            color: theme.rose.opacity(UI.Components.RecipeRow.Thumbnail.roseShadowOpacity * theme.shadowStrength),
            radius: UI.Components.RecipeRow.Thumbnail.roseShadowRadius,
            x: 0, y: UI.Components.RecipeRow.Thumbnail.roseShadowY
        )
        .shadow(
            color: .black.opacity(UI.Components.RecipeRow.Thumbnail.shadowOpacity * theme.shadowStrength),
            radius: UI.Components.RecipeRow.Thumbnail.secondaryShadowRadius,
            x: 0, y: UI.Components.RecipeRow.Thumbnail.secondaryShadowY
        )
    }

    private var styledImage: some View {
        let inset = UI.Components.RecipeRow.Thumbnail.inset
        return RecipeImage(recipe: recipe, height: UI.V2.recipeRowImageSize)
            .frame(
                width: UI.V2.recipeRowImageSize - (inset * 2),
                height: UI.V2.recipeRowImageSize - (inset * 2)
            )
            .saturation(UI.Components.RecipeRow.Thumbnail.saturation)
            .contrast(UI.Components.RecipeRow.Thumbnail.contrast)
            .overlay {
                LinearGradient(
                    colors: [
                        theme.sky.opacity(UI.Components.RecipeRow.Thumbnail.overlaySkyOpacity),
                        .clear,
                        theme.accent.opacity(UI.Components.RecipeRow.Thumbnail.overlayAccentOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(shape)
            .padding(inset)
    }

    private var thumbnailBackground: some View {
        shape
            .fill(theme.card)
            .overlay {
                shape.stroke(
                    theme.frostStrokeTop.opacity(UI.Components.RecipeRow.Thumbnail.borderOpacity),
                    lineWidth: UI.Common.borderWidth
                )
            }
    }
}

struct RecipeBadges: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe

    var body: some View {
        HStack(spacing: UI.RecipeBadge.spacing) {
            if isQuick {
                badge(Strings.Discover.badgeQuick, icon: Icons.Discover.badgeQuick, color: theme.sky)
                    .accessibilityIdentifier(AccessibilityID.Discover.badgeQuick(recipe.title))
            }
            if isEasy {
                badge(Strings.Discover.badgeEasy, icon: Icons.Discover.badgeEasy, color: theme.mint)
                    .accessibilityIdentifier(AccessibilityID.Discover.badgeEasy(recipe.title))
            }
            if isBeginnerFriendly {
                badge(Strings.Discover.badgeBeginner, icon: Icons.Discover.badgeBeginner, color: theme.lavender)
                    .accessibilityIdentifier(AccessibilityID.Discover.badgeBeginner(recipe.title))
            }
        }
    }

    private var isQuick: Bool {
        guard let minutes = recipe.cookTimeMinutes else { return false }
        return minutes <= UI.RecipeBadge.quickThresholdMinutes
    }

    private var isEasy: Bool {
        for info in recipe.additionalInfo.infos {
            if case .complexity(let level) = info {
                return level.lowercased() == "easy" || level.lowercased() == "low"
            }
        }
        return false
    }

    private var isBeginnerFriendly: Bool {
        let ingredients = recipe.cleanedIngredients.isEmpty ? recipe.ingredients : recipe.cleanedIngredients
        return ingredients.count > 0 && ingredients.count <= UI.RecipeBadge.beginnerMaxIngredients
    }

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(UI.Fonts.tinyCaption)
            .foregroundStyle(color)
            .padding(.horizontal, UI.RecipeBadge.paddingH)
            .padding(.vertical, UI.RecipeBadge.paddingV)
            .background(color.opacity(UI.RecipeBadge.backgroundOpacity), in: Capsule())
    }
}
