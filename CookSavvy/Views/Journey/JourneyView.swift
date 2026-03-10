import SwiftUI

struct JourneyView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: JourneyViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: UI.Journey.sectionSpacing) {
                profileHeader
                statsGrid
                myRecipesSection
                weeklyActivity
                achievementsSection
                recentActivitySection
                Spacer(minLength: UI.Common.bottomSpacerMinLength)
            }
            .padding(.horizontal, UI.Journey.horizontalPadding)
        }
        .background(theme.bg)
        .navigationTitle(Strings.Journey.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showSettings()
                } label: {
                    Image(systemName: Icons.Journey.settings)
                        .foregroundStyle(theme.text2)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: UI.Journey.profileSpacing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [theme.accent, theme.rose],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: UI.V2.avatarSize, height: UI.V2.avatarSize)
                Text("🧑‍🍳")
                    .font(.system(size: UI.Journey.emojiSize))
            }
            .neonGlow(theme.accent, radius: UI.Common.neonRadiusDefault)

            VStack(spacing: UI.Journey.profileNameSpacing) {
                Text(Strings.Journey.homeChef)
                    .font(UI.Fonts.profileName)
                    .foregroundStyle(theme.text1)
            }

            HStack(spacing: UI.Journey.levelSpacing) {
                Image(systemName: Icons.Journey.star)
                    .font(UI.Fonts.smallCaption)
                    .foregroundStyle(theme.gold)
                Text("Level \(max(1, viewModel.recipesCooked / 5))")
                    .font(UI.Fonts.captionBold)
                    .foregroundStyle(theme.gold)
            }
            .padding(.horizontal, UI.Journey.levelPaddingH)
            .padding(.vertical, UI.Journey.levelPaddingV)
            .background(theme.gold.opacity(UI.Journey.levelBadgeOpacity), in: Capsule())
        }
        .padding(.top, UI.Journey.profileTopPadding)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: UI.Journey.statsGridSpacing) {
            journeyStat(value: "\(viewModel.recipesCooked)", label: Strings.Journey.recipesCooked,
                        icon: Icons.Journey.forkKnife, color: theme.accent)
            journeyStat(value: "\(viewModel.dayStreak)", label: Strings.Journey.dayStreak,
                        icon: Icons.Journey.flame, color: theme.rose)
            journeyStat(value: String(format: "%.0f", viewModel.hoursCooking), label: Strings.Journey.hoursCooking,
                        icon: Icons.Journey.clock, color: theme.mint)
        }
    }

    private func journeyStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: UI.Journey.statItemSpacing) {
            Image(systemName: icon)
                .font(.system(size: UI.Journey.statIconSize, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(UI.Fonts.statValue)
                .foregroundStyle(theme.text1)
            Text(label)
                .font(UI.Fonts.tinyCaptionMedium)
                .foregroundStyle(theme.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UI.Journey.statItemPadding)
        .frostCard()
    }

    // MARK: - My Recipes

    private var myRecipesSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.myRecipesSpacing) {
            HStack {
                Text(Strings.Journey.myRecipes)
                    .sectionLabel()
                Spacer()
                if !viewModel.userRecipes.isEmpty {
                    Text("\(viewModel.userRecipes.count) recipes")
                        .font(UI.Fonts.smallCaptionMedium)
                        .foregroundStyle(theme.text3)
                    Button {
                        viewModel.showRecipeList(
                            title: Strings.RecipeList.myRecipes,
                            recipes: viewModel.userRecipes
                        )
                    } label: {
                        Text(Strings.Journey.seeAll)
                            .font(UI.Fonts.captionSemibold)
                            .foregroundStyle(theme.accent)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Journey.myRecipesSpacing) {
                    Button {
                        viewModel.showCreateRecipe()
                    } label: {
                        CreateRecipeCard()
                    }
                    .buttonStyle(.plain)

                    ForEach(viewModel.userRecipes) { recipe in
                        UserMiniRecipeCard(recipe: recipe)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.showRecipeDetails(recipe)
                            }
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }

            if viewModel.userRecipes.isEmpty {
                Text(Strings.Journey.shareCreations)
                    .font(UI.Fonts.caption)
                    .foregroundStyle(theme.text3)
            }
        }
    }

    // MARK: - Weekly Activity

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: UI.Journey.weeklySpacing) {
            Text(Strings.Journey.thisWeek)
                .sectionLabel()

            HStack(spacing: UI.Journey.dayCircleSpacing) {
                ForEach(Array(viewModel.weekdayLabels.enumerated()), id: \.offset) { index, day in
                    WeekdayDotView(
                        isActive: viewModel.isActiveDay(index),
                        isToday: viewModel.isTodayIndex(index),
                        label: day
                    )
                }
            }
            .padding(UI.Journey.weeklyPadding)
            .frostCard()
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.achievementSpacing) {
            HStack {
                Text(Strings.Journey.achievements)
                    .sectionLabel()
                Spacer()
                Text("\(viewModel.unlockedCount)/\(viewModel.achievements.count)")
                    .font(UI.Fonts.captionSemibold)
                    .foregroundStyle(theme.text2)
            }

            VStack(spacing: UI.Journey.statItemSpacing) {
                ForEach(viewModel.achievements) { achievement in
                    achievementRow(achievement)
                }
            }
        }
    }

    private func achievementRow(_ achievement: Achievement) -> some View {
        let color = Color(hex: achievement.colorHex)
        return HStack(spacing: UI.Journey.achievementRowSpacing) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? color.opacity(UI.Journey.achievementIconOpacity) : theme.surface)
                    .frame(width: UI.Journey.achievementIconSize, height: UI.Journey.achievementIconSize)
                Text(achievement.emoji)
                    .font(.system(size: UI.Journey.statIconSize))
            }
            .neonGlow(achievement.isUnlocked ? color : .clear, radius: UI.Common.neonRadiusMini)

            VStack(alignment: .leading, spacing: UI.Common.smallSpacing) {
                Text(achievement.title)
                    .font(UI.Fonts.sectionTitle)
                    .foregroundStyle(achievement.isUnlocked ? theme.text1 : theme.text2)

                Text(achievement.description)
                    .font(UI.Fonts.smallCaption)
                    .foregroundStyle(theme.text3)

                AchievementProgressBar(color: color, progressFraction: achievement.progressFraction)
            }

            Text("\(Int(achievement.progressFraction * 100))%")
                .font(UI.Fonts.smallCaptionBold)
                .foregroundStyle(color)
        }
        .padding(UI.Journey.achievementPadding)
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
    }

    // MARK: - Recent Activity

    @ViewBuilder
    private var recentActivitySection: some View {
        if !viewModel.recentSessions.isEmpty {
            VStack(alignment: .leading, spacing: UI.Journey.recentActivitySpacing) {
                Text(Strings.Journey.recentActivity)
                    .sectionLabel()

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentSessions.enumerated()), id: \.element.id) { index, session in
                        ActivitySessionRow(
                            session: session,
                            showDivider: index < viewModel.recentSessions.count - 1
                        )
                    }
                }
                .frostCard(cornerRadius: UI.Common.cardCornerRadius)
            }
        }
    }

}
