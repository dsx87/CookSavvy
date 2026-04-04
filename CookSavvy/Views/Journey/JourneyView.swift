import SwiftUI

struct JourneyView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: JourneyViewModel
    @State private var hasLoadedData = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: UI.Journey.sectionSpacing) {
                savedRecipesSection
                recentActivitySection
                shoppingListSection
                statsSection
                myRecipesSection
                achievementsSection
                Spacer(minLength: UI.Common.bottomSpacerMinLength)
            }
            .padding(.top, UI.Journey.contentTopPadding)
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
            guard !hasLoadedData else { return }
            hasLoadedData = true
            await viewModel.loadData()
        }
        .onAppear {
            guard hasLoadedData else { return }
            Task {
                await viewModel.refreshRecipeCollections()
            }
        }
    }

    private var savedRecipesSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.myRecipesSpacing) {
            HStack {
                Text(Strings.Journey.savedRecipes)
                    .sectionLabel()
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !viewModel.savedRecipes.isEmpty {
                    Button {
                        viewModel.showRecipeList(
                            title: Strings.RecipeList.savedRecipes,
                            recipes: viewModel.savedRecipes
                        )
                    } label: {
                        Text(Strings.Journey.seeAll)
                            .font(UI.Fonts.captionSemibold)
                            .foregroundStyle(theme.accent)
                    }
                }
            }

            if viewModel.savedRecipes.isEmpty {
                Text(Strings.Journey.savedRecipesEmpty)
                    .font(UI.Fonts.caption)
                    .foregroundStyle(theme.text3)
                    .padding(.vertical, UI.Journey.shortcutButtonPaddingV)
                    .padding(.horizontal, UI.Journey.shortcutHorizontalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frostCard(cornerRadius: UI.Common.cardCornerRadius)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UI.Journey.myRecipesSpacing) {
                        ForEach(viewModel.savedRecipes) { recipe in
                            MiniRecipeCard(recipe: recipe)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.showRecipeDetails(recipe)
                                }
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Journey.savedRecipes)
    }

    private var shoppingListSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.utilityCardSpacing) {
            Text(Strings.Journey.shoppingList)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            ShoppingListShortcutCard(isPremium: viewModel.subscriptionHasShoppingListAccess) {
                viewModel.showShoppingList()
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.compactSectionSpacing) {
            Text(Strings.Journey.kitchenStats)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            allTimeStatsContent
            monthlyStatsContent
            weeklyActivityContent
        }
    }

    private var allTimeStatsContent: some View {
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

    private var monthlyStatsContent: some View {
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

    private var weeklyActivityContent: some View {
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

    @ViewBuilder
    private var recentActivitySection: some View {
        if !viewModel.recentSessions.isEmpty {
            VStack(alignment: .leading, spacing: UI.Journey.recentActivitySpacing) {
                Text(Strings.Journey.recentCooks)
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
