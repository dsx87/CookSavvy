import SwiftUI

struct JourneyView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: JourneyViewModel

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
        .toolbar { settingsToolbarItem }
        .alert(Strings.Journey.cookAgainErrorTitle, isPresented: cookAgainErrorBinding) {
            cookAgainErrorDismissButton
        } message: {
            cookAgainErrorMessage
        }
        .task {
            await viewModel.loadDataIfNeeded()
        }
        .onAppear {
            viewModel.reloadDataOnAppear()
        }
    }

    private var settingsToolbarItem: some ToolbarContent {
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

    private var cookAgainErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.cookAgainErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissCookAgainError()
                }
            }
        )
    }

    private var cookAgainErrorDismissButton: some View {
        Button(Strings.Common.ok, role: .cancel) {
            viewModel.dismissCookAgainError()
        }
    }

    private var cookAgainErrorMessage: some View {
        Text(viewModel.cookAgainErrorMessage ?? "")
    }

    private var savedRecipesSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.myRecipesSpacing) {
            savedRecipesHeader
            savedRecipesContent
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

    private var savedRecipesHeader: some View {
        HStack {
            Text(Strings.Journey.savedRecipes)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !viewModel.savedRecipes.isEmpty {
                seeAllButton(
                    title: Strings.RecipeList.savedRecipes,
                    recipes: viewModel.savedRecipes
                )
            }
        }
    }

    @ViewBuilder
    private var savedRecipesContent: some View {
        if viewModel.savedRecipes.isEmpty {
            emptySavedRecipesView
        } else {
            savedRecipesCarousel
        }
    }

    private var emptySavedRecipesView: some View {
        Text(Strings.Journey.savedRecipesEmpty)
            .font(UI.Fonts.caption)
            .foregroundStyle(theme.text3)
            .padding(.vertical, UI.Journey.shortcutButtonPaddingV)
            .padding(.horizontal, UI.Journey.shortcutHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frostCard(cornerRadius: UI.Common.cardCornerRadius)
    }

    private var savedRecipesCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UI.Journey.myRecipesSpacing) {
                ForEach(viewModel.savedRecipes) { recipe in
                    recipeCard(recipe)
                }
            }
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

            weeklyActivityDots
            .padding(UI.Journey.weeklyPadding)
            .frostCard()
        }
        .accessibilityIdentifier(AccessibilityID.Journey.weeklyActivity)
    }

    private var myRecipesSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.myRecipesSpacing) {
            myRecipesHeader
            myRecipesCarousel

            if viewModel.userRecipes.isEmpty {
                Text(Strings.Journey.shareCreations)
                    .font(UI.Fonts.caption)
                    .foregroundStyle(theme.text3)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Journey.myRecipes)
    }

    private var weeklyActivityDots: some View {
        HStack(spacing: UI.Journey.dayCircleSpacing) {
            ForEach(Array(viewModel.weekdayLabels.enumerated()), id: \.offset) { index, day in
                WeekdayDotView(
                    isActive: viewModel.isActiveDay(index),
                    isToday: viewModel.isTodayIndex(index),
                    label: day
                )
            }
        }
    }

    private var myRecipesHeader: some View {
        HStack {
            Text(Strings.Journey.myRecipes)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !viewModel.userRecipes.isEmpty {
                Text(recipeCountText)
                    .font(UI.Fonts.smallCaptionMedium)
                    .foregroundStyle(theme.text3)
                seeAllButton(
                    title: Strings.RecipeList.myRecipes,
                    recipes: viewModel.userRecipes
                )
            }
        }
    }

    private var myRecipesCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UI.Journey.myRecipesSpacing) {
                createRecipeButton

                ForEach(viewModel.userRecipes) { recipe in
                    userRecipeCard(recipe)
                }
            }
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: UI.Journey.achievementSpacing) {
            achievementsHeader
            if viewModel.isAchievementsExpanded {
                achievementsCarousel
                    .accessibilityIdentifier(AccessibilityID.Journey.achievementsExpanded)
            } else {
                achievementsCompactCard
                    .accessibilityIdentifier(AccessibilityID.Journey.achievementsCompact)
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

                recentActivityContent
            }
            .accessibilityIdentifier(AccessibilityID.Journey.recentActivity)
        }
    }

    private var achievementsHeader: some View {
        HStack {
            Text(Strings.Journey.milestones)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Text(String(format: Strings.Journey.milestonesEarned, viewModel.unlockedCount, viewModel.achievements.count))
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(theme.text2)
        }
    }

    private var achievementsCompactCard: some View {
        VStack(alignment: .leading, spacing: UI.Journey.achievementCompactSpacing) {
            Text(Strings.Journey.achievementsSummary)
                .font(UI.Fonts.caption)
                .foregroundStyle(theme.text3)

            antiWasteAchievementsRow

            achievementsToggleButton(title: Strings.Journey.showAllMilestones, icon: Icons.Journey.chevronDown)
        }
        .padding(UI.Journey.achievementCompactPadding)
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
    }

    private var antiWasteAchievementsRow: some View {
        HStack(spacing: UI.Journey.achievementBadgeSpacing) {
            ForEach(viewModel.antiWasteAchievements) { achievement in
                achievementBadge(achievement)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(AccessibilityID.Journey.achievementsAntiWaste)
    }

    private var achievementsCarousel: some View {
        VStack(alignment: .leading, spacing: UI.Journey.achievementCompactSpacing) {
            achievementsToggleButton(title: Strings.Journey.hideMilestones, icon: Icons.Journey.chevronUp)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Journey.achievementBadgeSpacing) {
                    ForEach(viewModel.achievements) { achievement in
                        achievementBadge(achievement)
                    }
                }
                .padding(.horizontal, UI.Journey.achievementBadgeHorizontalPadding)
            }
        }
        .padding(UI.Journey.achievementCompactPadding)
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
    }

    private func achievementsToggleButton(title: String, icon: String) -> some View {
        Button {
            viewModel.toggleAchievementsExpanded()
        } label: {
            HStack(spacing: UI.Journey.achievementToggleSpacing) {
                Text(title)
                    .font(UI.Fonts.captionSemibold)
                Image(systemName: icon)
                    .font(UI.Fonts.smallCaptionBold)
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, UI.Journey.shortcutButtonPaddingH)
            .padding(.vertical, UI.Journey.shortcutButtonPaddingV)
            .background(theme.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Journey.achievementsToggle)
    }

    private var recentActivityContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.recentSessions.enumerated()), id: \.element.id) { index, session in
                ActivitySessionRow(
                    session: session,
                    showDivider: index < viewModel.recentSessions.count - 1,
                    onCookAgain: cookAgainAction(for: session)
                )
            }
        }
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
    }

    private var recipeCountText: String {
        String(format: Strings.Journey.recipeCount, viewModel.userRecipes.count)
    }

    private func seeAllButton(title: String, recipes: [Recipe]) -> some View {
        Button {
            viewModel.showRecipeList(title: title, recipes: recipes)
        } label: {
            Text(Strings.Journey.seeAll)
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(theme.accent)
        }
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        MiniRecipeCard(recipe: recipe)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.showRecipeDetails(recipe)
            }
            .accessibilityAddTraits(.isButton)
    }

    private var createRecipeButton: some View {
        Button {
            viewModel.showCreateRecipe()
        } label: {
            CreateRecipeCard()
        }
        .buttonStyle(.plain)
    }

    private func userRecipeCard(_ recipe: Recipe) -> some View {
        UserMiniRecipeCard(recipe: recipe)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.showRecipeDetails(recipe)
            }
            .accessibilityAddTraits(.isButton)
    }

    private func cookAgainAction(for session: CookingSession) -> () -> Void {
        {
            Task {
                await viewModel.cookAgain(session: session)
            }
        }
    }
}
