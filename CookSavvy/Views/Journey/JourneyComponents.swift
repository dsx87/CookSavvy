import SwiftUI

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
