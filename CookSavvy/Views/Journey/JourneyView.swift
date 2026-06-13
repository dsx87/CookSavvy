import SwiftUI

/// The My Kitchen (Journey) tab's root view.
///
/// Displays a scrollable feed of personalised content sections:
/// account status card, saved recipes carousel, shopping list shortcut,
/// kitchen stats (all-time, monthly, weekly activity), My Recipes carousel,
/// achievements section, and recent cooking activity.
struct JourneyView: View {
    @Environment(\.appTheme) private var theme
    @State var viewModel: JourneyViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: UI.Journey.sectionSpacing) {
                accountCardSection
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
        .alert(activeAlertTitle, isPresented: alertBinding) {
            Button(Strings.Common.ok, role: .cancel) {
                dismissActiveAlert()
            }
        } message: {
            Text(activeAlertMessage)
        }
        .task {
            await viewModel.loadDataIfNeeded()
        }
        .onAppear {
            viewModel.reloadDataOnAppear()
        }
    }

    /// Gear icon toolbar button that opens the Settings screen.
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

    /// Unified binding that is `true` when any alert (cook-again error or general error) is pending.
    private var alertBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.cookAgainErrorMessage != nil || viewModel.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    dismissActiveAlert()
                }
            }
        )
    }

    /// Title string for the currently pending alert, prioritising cook-again errors.
    private var activeAlertTitle: String {
        if viewModel.cookAgainErrorMessage != nil {
            return Strings.Journey.cookAgainErrorTitle
        }
        return Strings.Errors.errorAlertTitle
    }

    /// Body text for the currently pending alert.
    private var activeAlertMessage: String {
        if let cookAgainErrorMessage = viewModel.cookAgainErrorMessage {
            return cookAgainErrorMessage
        }
        return viewModel.errorMessage ?? ""
    }

    /// Clears all currently active Journey alerts.
    private func dismissActiveAlert() {
        viewModel.dismissCookAgainError()
        viewModel.dismissError()
    }

    /// Account status card — sign-in prompt for anonymous users, secured badge for Apple-linked accounts.
    @ViewBuilder
    private var accountCardSection: some View {
        if viewModel.isAuthAvailable {
            if viewModel.isSignedInWithApple {
                signedInCard
            } else {
                signInCard
            }
        }
    }

    private var signInCard: some View {
        HStack(spacing: UI.Journey.accountCardContentSpacing) {
            Image(systemName: Icons.Auth.personCircle)
                .font(.system(size: UI.Auth.accountIconSize))
                .foregroundStyle(theme.text3)
                .frame(width: UI.Auth.accountIconSize, height: UI.Auth.accountIconSize)

            VStack(alignment: .leading, spacing: UI.Journey.accountCardTextSpacing) {
                Text(Strings.Auth.guestAccount)
                    .font(UI.Fonts.bodySemibold)
                    .foregroundStyle(theme.text1)
                Text(Strings.Auth.signInSubtitle)
                    .font(UI.Fonts.caption)
                    .foregroundStyle(theme.text3)
            }

            Spacer()

            Button {
                Task { await viewModel.signInWithApple() }
            } label: {
                HStack(spacing: UI.Journey.accountCardButtonSpacing) {
                    if viewModel.isSigningIn {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: Icons.Auth.applelogo)
                            .font(UI.Fonts.caption)
                    }
                    Text(viewModel.isSigningIn ? Strings.Auth.signingIn : Strings.Journey.signIn)
                        .font(UI.Fonts.captionSemibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, UI.Journey.shortcutButtonPaddingH)
                .padding(.vertical, UI.Journey.shortcutButtonPaddingV)
                .background(theme.text1, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSigningIn)
        }
        .padding(UI.Journey.accountCardPadding)
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
        .accessibilityIdentifier(AccessibilityID.Journey.accountCard)
    }

    private var signedInCard: some View {
        HStack(spacing: UI.Journey.accountCardContentSpacing) {
            Image(systemName: Icons.Auth.checkmarkShield)
                .font(.system(size: UI.Journey.accountCardIconSize))
                .foregroundStyle(theme.mint)
                .frame(width: UI.Journey.accountCardIconSize, height: UI.Journey.accountCardIconSize)

            VStack(alignment: .leading, spacing: UI.Journey.accountCardTextSpacing) {
                Text(Strings.Auth.signedInAs)
                    .font(UI.Fonts.bodySemibold)
                    .foregroundStyle(theme.text1)
                Text(Strings.Journey.accountSecured)
                    .font(UI.Fonts.caption)
                    .foregroundStyle(theme.text3)
            }

            Spacer()
        }
        .padding(UI.Journey.accountCardPadding)
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
        .accessibilityIdentifier(AccessibilityID.Journey.accountCard)
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

    /// Individual stat tile used in both the all-time and monthly stats grids.
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
            if viewModel.showsMonthlyInsights {
                monthlyInsightsCard
            }
        }
        .accessibilityIdentifier(AccessibilityID.Journey.monthlyStats)
    }

    private var monthlyInsightsCard: some View {
        HStack(alignment: .top, spacing: UI.Journey.shortcutContentSpacing) {
            Image(systemName: Icons.Journey.savings)
                .font(.system(size: UI.Journey.statIconSize, weight: .semibold))
                .foregroundStyle(theme.gold)
                .frame(width: UI.Journey.accountCardIconSize, height: UI.Journey.accountCardIconSize)

            VStack(alignment: .leading, spacing: UI.Journey.shortcutTextSpacing) {
                Text(Strings.Journey.monthlyInsights)
                    .font(UI.Fonts.captionSemibold)
                    .foregroundStyle(theme.text2)
                Text(viewModel.monthlySavingsSummary)
                    .font(UI.Fonts.bodySemibold)
                    .foregroundStyle(theme.text1)
                    .accessibilityIdentifier(AccessibilityID.Journey.Stats.monthlySavings)
                Text(viewModel.monthlySavingsCaveat)
                    .font(UI.Fonts.tinyCaption)
                    .foregroundStyle(theme.text3)
            }

            Spacer(minLength: 0)
        }
        .padding(UI.Journey.accountCardPadding)
        .frostCard(cornerRadius: UI.Common.cardCornerRadius)
        .accessibilityIdentifier(AccessibilityID.Journey.monthlyInsights)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Strings.Journey.monthlyInsights): \(viewModel.monthlySavingsSummary). \(viewModel.monthlySavingsCaveat)")
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

    /// Seven capsule dots representing Mon–Sun; active days and today are highlighted differently.
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

    /// Achievement badge showing an emoji, neon glow (if unlocked), and title label.
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

    /// Button that toggles expanded/collapsed achievement presentation modes.
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

    /// "See All" button that navigates to the full recipe list for the given collection.
    private func seeAllButton(title: String, recipes: [Recipe]) -> some View {
        Button {
            viewModel.showRecipeList(title: title, recipes: recipes)
        } label: {
            Text(Strings.Journey.seeAll)
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(theme.accent)
        }
    }

    /// Tappable `MiniRecipeCard` that navigates to recipe detail.
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

    /// Tappable `UserMiniRecipeCard` for user-created recipes that navigates to recipe detail.
    private func userRecipeCard(_ recipe: Recipe) -> some View {
        UserMiniRecipeCard(recipe: recipe)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.showRecipeDetails(recipe)
            }
            .accessibilityAddTraits(.isButton)
    }

    /// Returns a closure that calls `cookAgain(session:)` on the view model when invoked.
    private func cookAgainAction(for session: CookingSession) -> () -> Void {
        {
            Task {
                await viewModel.cookAgain(session: session)
            }
        }
    }
}
