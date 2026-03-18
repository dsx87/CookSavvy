import SwiftUI

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
        .accessibilityIdentifier(AccessibilityID.Discover.category(category.rawValue))
        .accessibilityLabel(isSelected
            ? String(format: Strings.Accessibility.categorySelected, category.rawValue.capitalized)
            : String(format: Strings.Accessibility.categoryNotSelected, category.rawValue.capitalized))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .scaleEffect(reduceMotion ? 1.0 : (isSelected ? UI.Components.bubbleSelectedScale : 1.0))

            Text(ingredient.name)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? theme.accent : theme.text2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(AccessibilityID.Discover.ingredient(ingredient.name))
        .accessibilityLabel(isSelected
            ? String(format: Strings.Accessibility.ingredientSelected, ingredient.name)
            : String(format: Strings.Accessibility.ingredientNotSelected, ingredient.name))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
            .accessibilityLabel(String(format: Strings.Accessibility.removeIngredient, ingredient.name))
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
        .accessibilityIdentifier(AccessibilityID.Discover.mood(name))
        .accessibilityLabel(isSelected
            ? String(format: Strings.Accessibility.moodSelected, name)
            : String(format: Strings.Accessibility.moodNotSelected, name))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
