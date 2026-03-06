import SwiftUI

struct RecipeImage: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe
    var height: CGFloat = 200

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
                AsyncImageDisk(imageName: recipe.image) {
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
                RecipeImage(recipe: recipe, height: UI.V2.miniCardImageHeight)
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
                RecipeImage(recipe: recipe, height: UI.V2.recipeRowImageSize)
                    .frame(width: UI.V2.recipeRowImageSize)
                    .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: UI.Components.rowContentSpacing) {
                    Text(recipe.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text1)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let tagline = recipe.tagline {
                        Text(tagline)
                            .font(UI.Fonts.caption)
                            .foregroundStyle(theme.text2)
                            .lineLimit(1)
                    }

                    HStack(spacing: UI.Components.rowInfoSpacing) {
                        if let time = cookTimeText {
                            Label(time, systemImage: Icons.Discover.clock)
                        }
                        if let calories = caloriesText {
                            Label(calories, systemImage: Icons.Discover.flame)
                        }
                        if let rating = recipe.apiRating ?? recipe.userRating {
                            StarRating(rating: rating)
                        }
                    }
                    .font(UI.Fonts.tinyCaptionMedium)
                    .foregroundStyle(theme.text3)
                }

                Spacer()

                Image(systemName: isSaved ? Icons.Discover.bookmarkFill : Icons.Discover.bookmark)
                    .font(UI.Fonts.iconSemibold)
                    .foregroundStyle(isSaved ? theme.accent : theme.text3)
            }
            .padding(UI.Components.rowPadding)
            .frostCard(cornerRadius: UI.Common.cardCornerRadius)

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
}
