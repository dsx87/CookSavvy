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
        HStack(spacing: UI.Components.rowSpacing) {
            RecipeImage(recipe: recipe, height: UI.V2.recipeRowImageSize)
                .frame(width: UI.V2.recipeRowImageSize)
                .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: UI.Components.rowContentSpacing) {
                Text(recipe.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text1)
                    .lineLimit(1)

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

struct CategoryChip: View {
    @Environment(\.appTheme) private var theme
    let category: IngredientCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: UI.Components.categoryChipSpacing) {
            Text(IngredientEmojiProvider.emoji(for: category))
                .font(UI.Fonts.smallButton)
            Text(category.rawValue.capitalized)
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(isSelected ? .white : theme.text2)
        }
        .padding(.horizontal, UI.Components.categoryChipPaddingH)
        .padding(.vertical, UI.Components.categoryChipPaddingV)
        .background(
            Capsule().fill(isSelected ? AnyShapeStyle(categoryColor) : AnyShapeStyle(theme.surface))
        )
        .overlay(
            Capsule().strokeBorder(isSelected ? Color.clear : theme.divider, lineWidth: UI.Common.borderWidth)
        )
    }

    private var categoryColor: Color {
        switch category {
        case .proteins: return theme.rose
        case .veggies: return theme.mint
        case .dairy: return theme.gold
        case .grains: return theme.accent
        case .fruits: return theme.rose
        case .spices: return theme.lavender
        case .other: return theme.sky
        }
    }
}

struct IngredientBubble: View {
    @Environment(\.appTheme) private var theme
    let ingredient: Ingredient
    let isSelected: Bool

    var body: some View {
        VStack(spacing: UI.Components.bubbleSpacing) {
            ZStack {
                Circle()
                    .fill(isSelected ? theme.accentSoft : theme.surface)
                    .frame(width: UI.Components.bubbleSize, height: UI.Components.bubbleSize)
                    .overlay(
                        Circle().strokeBorder(isSelected ? theme.accent : theme.divider, lineWidth: isSelected ? UI.Components.bubbleSelectedBorder : UI.Common.borderWidth)
                    )
                Text(ingredient.emoji ?? IngredientEmojiProvider.emoji(for: ingredient.name, foodGroup: ingredient.foodGroup))
                    .font(.system(size: UI.Components.bubbleEmojiSize))
            }
            .scaleEffect(isSelected ? UI.Components.bubbleSelectedScale : 1.0)

            Text(ingredient.name)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? theme.accent : theme.text2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SelectedChip: View {
    @Environment(\.appTheme) private var theme
    let ingredient: Ingredient
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: UI.Components.selectedChipSpacing) {
            Text(ingredient.emoji ?? IngredientEmojiProvider.emoji(for: ingredient.name, foodGroup: ingredient.foodGroup))
                .font(UI.Fonts.caption)
            Text(ingredient.name)
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(theme.text1)
            Button(action: onRemove) {
                Image(systemName: Icons.SelectedIngredient.remove)
                    .font(UI.Fonts.microBold)
                    .foregroundStyle(theme.text3)
            }
        }
        .padding(.horizontal, UI.Components.selectedChipPaddingH)
        .padding(.vertical, UI.Components.selectedChipPaddingV)
        .background(theme.surface, in: Capsule())
        .overlay(
            Capsule().strokeBorder(theme.divider, lineWidth: UI.Common.borderWidth)
        )
    }
}

struct MoodPill: View {
    @Environment(\.appTheme) private var theme
    let name: String
    let icon: String
    let color: Color
    let gradient: [Color]
    let isSelected: Bool

    var body: some View {
        HStack(spacing: UI.Components.moodPillSpacing) {
            Image(systemName: icon)
                .font(UI.Fonts.smallButton)
            Text(name)
                .font(UI.Fonts.smallButton)
        }
        .foregroundStyle(isSelected ? .white : color)
        .padding(.horizontal, UI.Components.moodPillPaddingH)
        .padding(.vertical, UI.Components.moodPillPaddingV)
        .background(
            Capsule()
                .fill(isSelected ? AnyShapeStyle(
                    LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)
                ) : AnyShapeStyle(color.opacity(UI.Components.moodPillUnselectedOpacity)))
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? Color.clear : color.opacity(UI.Components.moodPillBorderOpacity), lineWidth: UI.Common.borderWidth)
        )
        .neonGlow(isSelected ? color : .clear, radius: isSelected ? UI.Components.moodPillGlowRadius : 0)
    }
}

struct StarRating: View {
    @Environment(\.appTheme) private var theme
    let rating: Double

    var body: some View {
        HStack(spacing: UI.Components.starSpacing) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating ? "star.fill" : (Double(i) - 0.5 <= rating ? "star.leadinghalf.filled" : "star"))
                    .font(UI.Fonts.micro)
                    .foregroundStyle(theme.gold)
            }
        }
    }
}

struct StatPill: View {
    @Environment(\.appTheme) private var theme
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: UI.Components.statPillSpacing) {
            Image(systemName: icon)
                .font(UI.Fonts.iconSemibold)
                .foregroundStyle(color)
            Text(value)
                .font(UI.Fonts.statPillValue)
                .foregroundStyle(theme.text1)
            Text(label)
                .font(UI.Fonts.statPillLabel)
                .foregroundStyle(theme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UI.Components.statPillPadding)
    }
}

struct AddYourOwnCard: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: UI.Components.addCardSpacing) {
            ZStack {
                theme.surface
                    .frame(height: UI.V2.miniCardImageHeight)

                VStack(spacing: UI.Components.addCardIconSpacing) {
                    Image(systemName: Icons.Discover.plus)
                        .font(UI.Fonts.profileName)
                        .foregroundStyle(theme.accent)
                    Text(Strings.Discover.addYourOwn)
                        .font(UI.Fonts.tinyCaptionMedium)
                        .foregroundStyle(theme.text3)
                }
            }
        }
        .frame(width: UI.V2.miniCardWidth, height: UI.Components.addCardHeight)
        .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: UI.Components.addCardDashWidth, dash: UI.Components.addCardDashPattern))
                .foregroundStyle(theme.divider)
        )
    }
}

struct CreateRecipeCard: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: UI.Components.createCardSpacing) {
            ZStack {
                LinearGradient(
                    colors: [theme.accent.opacity(UI.CreateRecipe.opacitySubtle), theme.accent.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: UI.V2.miniCardImageHeight)

                Image(systemName: Icons.Journey.plus)
                    .font(UI.Fonts.largeTitle)
                    .foregroundStyle(theme.accent)
                    .neonGlow(theme.accent, radius: UI.Common.neonRadiusTiny)
            }

            VStack(spacing: UI.Components.createCardTitleSpacing) {
                Text(Strings.Journey.addRecipe)
                    .font(UI.Fonts.captionBold)
                    .foregroundStyle(theme.text1)
                    .lineLimit(1)
            }
            .padding(.horizontal, UI.Components.miniCardPaddingH)
            .padding(.vertical, UI.Components.miniCardPaddingV)
        }
        .frame(width: UI.V2.miniCardWidth)
        .clipShape(RoundedRectangle(cornerRadius: UI.Common.cardCornerRadius, style: .continuous))
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
    }
}

struct UserMiniRecipeCard: View {
    @Environment(\.appTheme) private var theme
    let recipe: Recipe

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MiniRecipeCard(recipe: recipe)

            Image(systemName: "pencil.circle.fill")
                .font(.system(size: UI.Components.userCardIconSize))
                .foregroundStyle(theme.accent)
                .background(theme.card, in: Circle())
                .offset(x: -UI.Components.userCardOffset, y: UI.Components.userCardOffset)
        }
    }
}
