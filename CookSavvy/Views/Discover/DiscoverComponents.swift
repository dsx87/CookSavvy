import SwiftUI

/// A styled chip button for selecting an ingredient category.
/// Displays the category emoji and name with selection state feedback (color, border).
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

/// A bubble-grid cell for ingredient selection.
/// Shows ingredient emoji, name, and animated selection state with optional motion reduction.
struct IngredientBubble: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ingredient: Ingredient
    let isSelected: Bool
    let isPantryItem: Bool
    let onSelect: () -> Void
    let onPantryToggle: () -> Void

    var body: some View {
        VStack(spacing: UI.Components.bubbleSpacing) {
            ZStack(alignment: .topTrailing) {
                ingredientButton
                pantryButton
            }
            .scaleEffect(reduceMotion ? 1.0 : (isSelected ? UI.Components.bubbleSelectedScale : 1.0))

            Text(ingredient.name.capitalized)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundStyle(labelColor)
                .lineLimit(1)

            Text(Strings.Discover.alwaysHaveBadge)
                .font(UI.Fonts.microBold)
                .foregroundStyle(isPantryItem ? theme.mint : .clear)
                .padding(.horizontal, UI.Components.alwaysHaveBadgePaddingH)
                .padding(.vertical, UI.Components.alwaysHaveBadgePaddingV)
                .background(isPantryItem ? theme.mintSoft : Color.clear, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(isPantryItem ? theme.mint.opacity(0.4) : Color.clear, lineWidth: UI.Common.borderWidth)
                )
                .opacity(isPantryItem ? 1 : 0)
                .accessibilityHidden(!isPantryItem)
        }
        .frame(maxWidth: .infinity)
    }

    private var ingredientButton: some View {
        Button(action: onSelect) {
            ZStack {
                Circle()
                    .fill(bubbleFill)
                    .frame(width: UI.Components.bubbleSize, height: UI.Components.bubbleSize)
                    .overlay(
                        Circle().strokeBorder(bubbleBorder, lineWidth: isSelected ? UI.Components.bubbleSelectedBorder : UI.Common.borderWidth)
                    )
                Text(ingredient.emoji ?? IngredientEmojiProvider.emoji(for: ingredient.name, foodGroup: ingredient.foodGroup))
                    .font(.system(size: UI.Components.bubbleEmojiSize))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Discover.ingredient(ingredient.name))
        .accessibilityLabel(isSelected
            ? String(format: Strings.Accessibility.ingredientSelected, ingredient.name)
            : String(format: Strings.Accessibility.ingredientNotSelected, ingredient.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var pantryButton: some View {
        Button(action: onPantryToggle) {
            Image(systemName: isPantryItem ? Icons.Discover.pantryFill : Icons.Discover.pantry)
                .font(.system(size: UI.Components.pantryToggleIconSize, weight: .bold))
                .foregroundStyle(isPantryItem ? .white : theme.text3)
                .frame(width: UI.Components.pantryToggleSize, height: UI.Components.pantryToggleSize)
                .background(isPantryItem ? theme.mint : theme.surfaceLight, in: Circle())
                .overlay(
                    Circle().strokeBorder(isPantryItem ? Color.clear : theme.divider, lineWidth: UI.Common.borderWidth)
                )
        }
        .frame(width: UI.Components.pantryToggleHitSize, height: UI.Components.pantryToggleHitSize)
        .contentShape(Circle())
        .buttonStyle(.plain)
        .offset(
            x: (UI.Components.pantryToggleHitSize - UI.Components.pantryToggleSize) / 2 + UI.Components.pantryToggleOffset,
            y: -((UI.Components.pantryToggleHitSize - UI.Components.pantryToggleSize) / 2 + UI.Components.pantryToggleOffset)
        )
        .accessibilityIdentifier(AccessibilityID.Discover.pantryToggle(ingredient.name))
        .accessibilityLabel(String(
            format: isPantryItem ? Strings.Accessibility.removeAlwaysHave : Strings.Accessibility.markAlwaysHave,
            ingredient.name
        ))
        .accessibilityAddTraits(isPantryItem ? [.isButton, .isSelected] : .isButton)
    }

    private var bubbleFill: Color {
        if isSelected { return theme.accentSoft }
        if isPantryItem { return theme.mintSoft }
        return theme.surface
    }

    private var bubbleBorder: Color {
        if isSelected { return theme.accent }
        if isPantryItem { return theme.mint }
        return theme.divider
    }

    private var labelColor: Color {
        if isSelected { return theme.accent }
        if isPantryItem { return theme.mint }
        return theme.text2
    }
}

/// A removable chip displaying a selected ingredient.
/// Shows emoji, name, and a remove button for deselection.
struct SelectedChip: View {
    @Environment(\.appTheme) private var theme
    let ingredient: Ingredient
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: UI.Components.selectedChipSpacing) {
            Text(ingredient.emoji ?? IngredientEmojiProvider.emoji(for: ingredient.name, foodGroup: ingredient.foodGroup))
                .font(UI.Fonts.caption)
            Text(ingredient.name.capitalized)
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

/// A read-only chip for pantry staples that are automatically included in Discover searches.
struct AlwaysHaveChip: View {
    @Environment(\.appTheme) private var theme
    let ingredient: Ingredient

    var body: some View {
        HStack(spacing: UI.Components.selectedChipSpacing) {
            Text(ingredient.emoji ?? IngredientEmojiProvider.emoji(for: ingredient.name, foodGroup: ingredient.foodGroup))
                .font(UI.Fonts.caption)
            Text(ingredient.name.capitalized)
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(theme.text1)
        }
        .padding(.horizontal, UI.Components.selectedChipPaddingH)
        .padding(.vertical, UI.Components.selectedChipPaddingV)
        .background(theme.mintSoft, in: Capsule())
        .overlay(
            Capsule().strokeBorder(theme.mint.opacity(0.35), lineWidth: UI.Common.borderWidth)
        )
        .accessibilityIdentifier(AccessibilityID.Discover.alwaysHaveChip(ingredient.name))
    }
}

/// A mood filter selection pill with icon and neon glow when selected.
/// Used in recipe results to filter by cooking mood (e.g. "Quick", "Comforting").
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

/// A compact result-filter pill used for time and difficulty filters.
struct RecipeFilterPill: View {
    let name: String
    let isSelected: Bool
    let accessibilityIdentifier: String

    var body: some View {
        Text(name)
            .font(UI.Fonts.smallButton)
            .foregroundStyle(isSelected ? .white : UI.Discover.Mood.freshColor)
            .padding(.horizontal, UI.Components.moodPillPaddingH)
            .padding(.vertical, UI.Components.moodPillPaddingV)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(
                        LinearGradient(colors: UI.Discover.Mood.freshGradient, startPoint: .leading, endPoint: .trailing)
                    ) : AnyShapeStyle(UI.Discover.Mood.freshColor.opacity(UI.Components.moodPillUnselectedOpacity)))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : UI.Discover.Mood.freshColor.opacity(UI.Components.moodPillBorderOpacity),
                        lineWidth: UI.Common.borderWidth
                    )
            )
            .neonGlow(isSelected ? UI.Discover.Mood.freshColor : .clear, radius: isSelected ? UI.Components.moodPillGlowRadius : 0)
            .accessibilityIdentifier(accessibilityIdentifier)
            .accessibilityLabel(isSelected
                ? String(format: Strings.Accessibility.filterSelected, name)
                : String(format: Strings.Accessibility.filterNotSelected, name))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A dashed-border card prompting the user to create a custom ingredient or recipe.
/// Appears in ingredient/recipe grid as a call-to-action cell.
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
