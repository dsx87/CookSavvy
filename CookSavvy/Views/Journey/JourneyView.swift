import SwiftUI

struct JourneyView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: JourneyViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: UI.Journey.sectionSpacing) {
                profileHeader
                statsGrid
                monthlyStatsSection
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
                .accessibilityIdentifier(AccessibilityID.Journey.settingsButton)
                .accessibilityLabel(Strings.Accessibility.settingsButton)
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

            Text(Strings.Journey.homeChef)
                .font(UI.Fonts.profileName)
                .foregroundStyle(theme.text1)
        }
        .padding(.top, UI.Journey.profileTopPadding)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: UI.Journey.statsGridSpacing) {
            Text(Strings.Journey.allTime)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: UI.Journey.statsGridSpacing) {
                journeyStat(value: "\(viewModel.recipesCooked)", label: Strings.Journey.recipesCooked,
                            icon: Icons.Journey.forkKnife, color: theme.accent,
                            accessibilityID: AccessibilityID.Journey.Stats.recipesCooked)
                journeyStat(value: "\(viewModel.uniqueIngredientsUsed)", label: Strings.Journey.ingredientsRescued,
                            icon: Icons.Journey.leaf, color: theme.mint,
                            accessibilityID: AccessibilityID.Journey.Stats.ingredientsRescued)
                journeyStat(value: viewModel.cookingTimeFormatted, label: Strings.Journey.hoursCooking,
                            icon: Icons.Journey.clock, color: theme.mint,
                            accessibilityID: AccessibilityID.Journey.Stats.hoursCooking)
            }
        }
    }

    private func journeyStat(value: String, label: String, icon: String, color: Color, accessibilityID: String) -> some View {
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
        .accessibilityIdentifier(accessibilityID)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label.replacingOccurrences(of: "\n", with: " ")): \(value)")
    }

    // MARK: - Monthly Stats

    private var monthlyStatsSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.statsGridSpacing) {
            Text(Strings.Journey.thisMonth)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: UI.Journey.statsGridSpacing) {
                journeyStat(
                    value: "\(viewModel.monthlyRecipesCooked)",
                    label: Strings.Journey.monthlyMeals,
                    icon: Icons.Journey.forkKnife,
                    color: theme.accent,
                    accessibilityID: AccessibilityID.Journey.Stats.monthlyMeals
                )
                journeyStat(
                    value: "\(viewModel.monthlyIngredientsRescued)",
                    label: Strings.Journey.monthlyRescued,
                    icon: Icons.Journey.leaf,
                    color: theme.mint,
                    accessibilityID: AccessibilityID.Journey.Stats.monthlyIngredients
                )
            }
        }
        .accessibilityIdentifier(AccessibilityID.Journey.monthlyStats)
    }

    // MARK: - My Recipes

    private var myRecipesSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.myRecipesSpacing) {
            HStack {
                Text(Strings.Journey.myRecipes)
                    .sectionLabel()
                    .accessibilityAddTraits(.isHeader)
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
        .accessibilityIdentifier(AccessibilityID.Journey.myRecipes)
    }

    // MARK: - Weekly Activity

    private var weeklyActivity: some View {
        VStack(alignment: .leading, spacing: UI.Journey.weeklySpacing) {
            Text(Strings.Journey.thisWeek)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

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
        .accessibilityIdentifier(AccessibilityID.Journey.weeklyActivity)
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.achievementSpacing) {
            HStack {
                Text(Strings.Journey.milestones)
                    .sectionLabel()
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(String(format: Strings.Journey.milestonesEarned, viewModel.unlockedCount, viewModel.achievements.count))
                    .font(UI.Fonts.captionSemibold)
                    .foregroundStyle(theme.text2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Journey.achievementBadgeSpacing) {
                    ForEach(viewModel.achievements) { achievement in
                        achievementBadge(achievement)
                    }
                }
                .padding(.horizontal, UI.Journey.achievementBadgeHorizontalPadding)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Journey.achievements)
    }

    private func achievementBadge(_ achievement: Achievement) -> some View {
        let color = Color(hex: achievement.colorHex)
        return VStack(spacing: UI.Journey.achievementBadgeLabelSpacing) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? color.opacity(UI.Journey.achievementIconOpacity) : theme.surface)
                    .frame(width: UI.Journey.achievementBadgeSize, height: UI.Journey.achievementBadgeSize)
                    .overlay {
                        Circle()
                            .stroke(achievement.isUnlocked ? color.opacity(UI.Journey.achievementBadgeStrokeOpacity) : theme.divider, lineWidth: UI.Common.borderWidth)
                    }
                Text(achievement.emoji)
                    .font(.system(size: UI.Journey.achievementBadgeEmojiSize))
                    .grayscale(achievement.isUnlocked ? 0 : 1)
                    .opacity(achievement.isUnlocked ? 1 : UI.Journey.achievementBadgeLockedOpacity)
            }
            .neonGlow(achievement.isUnlocked ? color : .clear, radius: UI.Common.neonRadiusMini)

            Text(achievement.title)
                .font(UI.Fonts.tinyCaption)
                .foregroundStyle(achievement.isUnlocked ? theme.text2 : theme.text3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: UI.Journey.achievementBadgeWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(achievement.accessibilityLabel)
    }

    // MARK: - Recent Activity

    @ViewBuilder
    private var recentActivitySection: some View {
        if !viewModel.recentSessions.isEmpty {
            VStack(alignment: .leading, spacing: UI.Journey.recentActivitySpacing) {
                Text(Strings.Journey.recentActivity)
                    .sectionLabel()
                    .accessibilityAddTraits(.isHeader)

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
            .accessibilityIdentifier(AccessibilityID.Journey.recentActivity)
        }
    }

}
