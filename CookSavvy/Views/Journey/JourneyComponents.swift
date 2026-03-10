import SwiftUI

struct WeekdayDotView: View {
    @Environment(\.appTheme) private var theme
    let isActive: Bool
    let isToday: Bool
    let label: String

    var body: some View {
        VStack(spacing: UI.Journey.dayCircleSpacing) {
            Circle()
                .fill(isActive ? theme.accent : theme.surface)
                .frame(width: UI.Journey.dayCircleSize, height: UI.Journey.dayCircleSize)
                .overlay(
                    Group {
                        if isActive {
                            Image(systemName: Icons.Journey.checkmark)
                                .font(UI.Fonts.smallCaptionBold)
                                .foregroundStyle(.white)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .strokeBorder(isToday ? theme.accent : .clear, lineWidth: UI.Journey.dayTodayBorderWidth)
                        .frame(width: UI.Journey.dayTodayCircleSize, height: UI.Journey.dayTodayCircleSize)
                )

            Text(label)
                .font(UI.Fonts.tinyCaptionMedium)
                .foregroundStyle(isToday ? theme.accent : theme.text3)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AchievementProgressBar: View {
    @Environment(\.appTheme) private var theme
    let color: Color
    let progressFraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.surface)
                    .frame(height: UI.Journey.achievementProgressHeight)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * progressFraction, height: UI.Journey.achievementProgressHeight)
            }
        }
        .frame(height: UI.Journey.achievementProgressHeight)
    }
}

struct ActivitySessionRow: View {
    @Environment(\.appTheme) private var theme
    let session: CookingSession
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: UI.Journey.activityRowSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: UI.Journey.activityIconCornerRadius, style: .continuous)
                        .fill(theme.accentSoft)
                        .frame(width: UI.Journey.activityIconSize, height: UI.Journey.activityIconSize)
                    Image(systemName: Icons.Journey.forkKnife)
                        .font(UI.Fonts.iconMedium)
                        .foregroundStyle(theme.accent)
                }

                VStack(alignment: .leading, spacing: UI.Journey.activityTextSpacing) {
                    Text(session.recipeTitle)
                        .font(UI.Fonts.smallButton)
                        .foregroundStyle(theme.text1)
                    Text(relativeDate(session.cookedAt))
                        .font(UI.Fonts.tinyCaption)
                        .foregroundStyle(theme.text3)
                }
                Spacer()
                if let duration = session.durationFormatted {
                    Text(duration)
                        .font(UI.Fonts.smallCaptionMedium)
                        .foregroundStyle(theme.text3)
                }
            }
            .padding(.vertical, UI.Journey.activityVerticalPadding)
            .padding(.horizontal, UI.Journey.activityHorizontalPadding)

            if showDivider {
                Divider()
                    .background(theme.divider)
                    .padding(.leading, UI.Journey.activityDividerLeading)
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
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
