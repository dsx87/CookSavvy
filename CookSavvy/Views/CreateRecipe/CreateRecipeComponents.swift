import SwiftUI

/// Selectable emoji bubble used in the recipe cover emoji picker.
struct EmojiPickerCell: View {
    @Environment(\.appTheme) private var theme
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(emoji)
            .font(UI.Fonts.largeTitle)
            .frame(width: UI.CreateRecipe.emojiSize, height: UI.CreateRecipe.emojiSize)
            .background(
                Circle()
                    .fill(isSelected ? theme.accentSoft : theme.surface)
            )
            .overlay(
                Circle()
                    .strokeBorder(isSelected ? theme.accent : theme.divider,
                                  lineWidth: isSelected ? UI.Components.bubbleSelectedBorder : UI.Common.borderWidth)
            )
            .scaleEffect(isSelected ? UI.CreateRecipe.emojiSelectedScale : 1.0)
            .onTapGesture {
                withAnimation(UI.Anim.springQuick) { onTap() }
            }
    }
}

/// Editable row for entering one instruction step in the create-recipe wizard.
struct StepInputRow: View {
    @Environment(\.appTheme) private var theme
    let index: Int
    @Binding var text: String
    /// Shared focus state for the wizard's text inputs; lets the keyboard toolbar's Done button
    /// dismiss this field. A single `Bool` is sufficient — we only need dismiss-all, not field nav.
    let focused: FocusState<Bool>.Binding
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: UI.CreateRecipe.stepRowItemSpacing) {
            Text("\(index + 1)")
                .font(UI.Fonts.stepNumber)
                .foregroundStyle(theme.onAccent)
                .frame(width: UI.RecipeDetails.stepNumberSize, height: UI.RecipeDetails.stepNumberSize)
                .background(
                    LinearGradient(colors: [theme.accent, theme.rose],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
                .padding(.top, UI.CreateRecipe.stepNumberTopPadding)

            TextField(String(format: Strings.CreateRecipe.stepPlaceholder, Int64(index + 1)), text: $text, axis: .vertical)
                .font(UI.Fonts.bodyRounded)
                .foregroundStyle(theme.text1)
                .focused(focused)
                .lineLimit(UI.CreateRecipe.stepTextLineLimit)
                .padding(UI.CreateRecipe.ingredientInputPadding)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: UI.CreateRecipe.ingredientInputCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: UI.CreateRecipe.ingredientInputCornerRadius, style: .continuous)
                        .strokeBorder(theme.divider, lineWidth: UI.Common.borderWidth)
                )
                .accessibilityIdentifier(AccessibilityID.CreateRecipe.step(index))

            if canDelete {
                Button {
                    withAnimation(UI.Anim.springQuick) { onDelete() }
                } label: {
                    Image(systemName: Icons.Settings.trash)
                        .font(UI.Fonts.smallButton)
                        .foregroundStyle(theme.text3)
                }
                .padding(.top, UI.CreateRecipe.stepDeleteTopPadding)
            }
        }
    }
}

/// Selectable chip representing a cook-time preset in minutes.
struct CookTimeChip: View {
    @Environment(\.appTheme) private var theme
    let time: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(String(format: Strings.Common.minutesCompact, Int64(time)))
            .font(UI.Fonts.smallButton)
            .foregroundStyle(isSelected ? .white : theme.text2)
            .padding(.horizontal, UI.CreateRecipe.cookTimeChipPaddingH)
            .padding(.vertical, UI.CreateRecipe.cookTimeChipPaddingV)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : theme.surface)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : theme.divider, lineWidth: UI.Common.borderWidth)
            )
            .onTapGesture {
                withAnimation(UI.Anim.easeQuick) { onTap() }
            }
    }
}

/// Selectable difficulty option button used in the details step.
struct DifficultyButton: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(title)
            .font(UI.Fonts.smallButton)
            .foregroundStyle(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, UI.CreateRecipe.difficultyPaddingV)
            .background(
                RoundedRectangle(cornerRadius: UI.CreateRecipe.ingredientInputCornerRadius, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(UI.CreateRecipe.opacityFaint)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: UI.CreateRecipe.ingredientInputCornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : color.opacity(UI.CreateRecipe.opacityLight), lineWidth: UI.Common.borderWidth)
            )
            .onTapGesture {
                withAnimation(UI.Anim.easeQuick) { onTap() }
            }
    }
}
