import SwiftUI

struct RecipeImage: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe
    var height: CGFloat = 200
    var contentMode: ContentMode = .fit

    var body: some View {
        ZStack {
            if recipe.image.isEmpty || recipe.image == "recipe_placeholder" {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(recipe.emoji ?? "🍽️")
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
                        Text(recipe.emoji ?? "🍽️")
                            .font(.system(size: height * UI.Components.emojiScaleFactor))
                            .shadow(color: .black.opacity(UI.Components.emojiShadowOpacity), radius: UI.Components.emojiShadowRadius, y: UI.Components.emojiShadowY)
                    }
                }
            }
        }
        .frame(height: height)
        .clipped()
    }

    private var gradientColors: [Color] {
        let base = theme.accent
        let secondary = theme.rose
        return [base, secondary]
    }
}

struct MiniRecipeCard: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                RecipeImage(recipe: recipe, height: UI.V2.miniCardImageHeight, contentMode: .fill)
                    .frame(width: UI.V2.miniCardWidth)

                VStack(alignment: .leading, spacing: UI.Components.miniCardContentSpacing) {
                    Text(recipe.title)
                        .font(UI.Fonts.captionBold)
                        .foregroundStyle(theme.text1)
                        .lineLimit(1)

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

            if let source = RecipeDisplaySource(recipe: recipe) {
                RecipeSourceBadge(source: source, cornerRadius: UI.Common.cardCornerRadius)
            }
        }
        .frame(width: UI.V2.miniCardWidth)
        .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
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
        ZStack(alignment: .topTrailing) {
            HStack(spacing: UI.Components.rowSpacing) {
                rowThumbnail

                VStack(alignment: .leading, spacing: UI.Components.rowContentSpacing) {
                    Text(recipe.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text1)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let tagline = recipe.tagline {
                        Text(tagline)
                            .font(UI.Fonts.caption)
                            .foregroundStyle(theme.text2)
                            .lineLimit(2)
                    }

                    HStack(spacing: UI.Components.rowInfoSpacing) {
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

                    Spacer(minLength: 0)
                }

                bookmarkBadge
            }
            .padding(UI.Components.rowPadding)
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))
            .shadow(
                color: theme.accent.opacity(0.10),
                radius: UI.Components.rowCardShadowRadius,
                x: 0,
                y: UI.Components.rowCardShadowY
            )
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)

            if let source = RecipeDisplaySource(recipe: recipe) {
                RecipeSourceBadge(source: source, cornerRadius: UI.Common.cardCornerRadius)
            }
        }
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
        let shape = RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous)

        return ZStack {
            shape
                .fill(theme.surfaceLight)

            RecipeImage(recipe: recipe, height: UI.V2.recipeRowImageSize)
                .frame(
                    width: UI.V2.recipeRowImageSize - (UI.Components.rowThumbnailInset * 2),
                    height: UI.V2.recipeRowImageSize - (UI.Components.rowThumbnailInset * 2)
                )
                .saturation(1.04)
                .contrast(1.03)
                .overlay {
                    LinearGradient(
                        colors: [
                            theme.sky.opacity(0.08),
                            .clear,
                            theme.accent.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(shape)
                .padding(UI.Components.rowThumbnailInset)
        }
        .frame(width: UI.V2.recipeRowImageSize, height: UI.V2.recipeRowImageSize)
        .background(
            shape
                .fill(theme.card)
                .overlay {
                    shape
                        .stroke(theme.frostStrokeTop.opacity(0.65), lineWidth: UI.Common.borderWidth)
                }
        )
        .shadow(
            color: theme.accent.opacity(0.16),
            radius: UI.Components.rowThumbnailShadowRadius,
            x: 0,
            y: UI.Components.rowThumbnailShadowY - 2
        )
        .shadow(color: theme.rose.opacity(0.08), radius: 12, x: 0, y: 8)
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
    }

    private var bookmarkBadge: some View {
        Image(systemName: isSaved ? Icons.Discover.bookmarkFill : Icons.Discover.bookmark)
            .font(UI.Fonts.iconSemibold)
            .foregroundStyle(isSaved ? theme.accent : theme.text3)
            .frame(width: UI.Components.rowBookmarkSize, height: UI.Components.rowBookmarkSize)
            .background(theme.surface.opacity(0.72), in: Circle())
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
                        theme.card.opacity(0.98),
                        theme.surface.opacity(0.92)
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
                        theme.frostStrokeTop.opacity(0.9),
                        theme.frostStrokeBottom.opacity(0.9)
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
            .padding(.horizontal, UI.Components.rowMetaPaddingH)
            .padding(.vertical, UI.Components.rowMetaPaddingV)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func rowRating(_ rating: Double) -> some View {
        HStack(spacing: UI.Components.rowInfoSpacing / 2) {
            StarRating(rating: rating)
            Text(String(format: "%.1f", rating))
                .font(UI.Fonts.tinyCaptionMedium)
                .foregroundStyle(theme.text2)
        }
        .padding(.horizontal, UI.Components.rowMetaPaddingH)
        .padding(.vertical, UI.Components.rowMetaPaddingV)
        .background(theme.gold.opacity(0.12), in: Capsule())
    }
}
