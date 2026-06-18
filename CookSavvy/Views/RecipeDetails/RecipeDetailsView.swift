import SwiftUI

/// The Recipe Details screen.
///
/// Presents a scrollable layout with a full-width hero image followed by a content card containing:
/// title, match reason chip, stats row, ingredient list with availability dots,
/// step-by-step instructions, and a sticky "Start Cooking" CTA.
///
/// A floating back button and bookmark toggle are overlaid on the hero image.
/// For premium users with missing ingredients, an "Add Missing to List" button appears in the
/// ingredients section.
struct RecipeDetailsView: View {
    var viewModel: RecipeDetailsViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    RecipeImage(recipe: viewModel.recipe, height: UI.V2.heroImageHeight)
                    contentCard
                }
            }
            startCookingButton
        }
        .background(theme.bg)
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
        .alert(Strings.Errors.errorAlertTitle, isPresented: errorBinding) {
            Button(Strings.Common.ok, role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                shareButton
                Button {
                    Task { await viewModel.toggleFavorite() }
                } label: {
                    Image(systemName: viewModel.isFavorite ? Icons.Discover.bookmarkFill : Icons.Discover.bookmark)
                        .foregroundStyle(viewModel.isFavorite ? theme.accent : theme.text2)
                }
                .disabled(viewModel.isLoadingFavorite)
                .accessibilityIdentifier(AccessibilityID.RecipeDetails.bookmarkButton)
                .accessibilityLabel(viewModel.isFavorite ? Strings.Accessibility.removeFromFavorites : Strings.Accessibility.addToFavorites)
            }
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        if let shareCard = viewModel.shareCard {
            ShareLink(
                item: shareCard,
                subject: Text(viewModel.recipe.title),
                message: Text(viewModel.recipe.shareText),
                preview: SharePreview(viewModel.recipe.title)
            ) {
                Image(systemName: Icons.RecipeDetails.share)
                    .foregroundStyle(theme.text2)
            }
            .accessibilityLabel(Strings.Accessibility.shareRecipe)
        } else {
            Button {} label: {
                Image(systemName: Icons.RecipeDetails.share)
                    .foregroundStyle(theme.text2)
            }
            .disabled(viewModel.isPreparingShareCard)
            .accessibilityLabel(Strings.Accessibility.shareRecipe)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissError()
                }
            }
        )
    }

    /// White rounded card below the hero image containing all recipe metadata and steps.
    private var contentCard: some View {
        VStack(alignment: .leading, spacing: UI.RecipeDetails.sectionSpacing) {
            recipeHeader
            statsRow
            ingredientsSection
            stepsSection
            Spacer(minLength: UI.Common.bottomSpacerMinLength)
        }
        .padding(UI.RecipeDetails.contentPadding)
        .background(theme.bg)
        .clipShape(.rect(topLeadingRadius: UI.RecipeDetails.contentTopCornerRadius, topTrailingRadius: UI.RecipeDetails.contentTopCornerRadius))
        .offset(y: -UI.V2.contentOverlapOffset)
    }

    /// Title, optional match-reason chip, and floating back/bookmark button row.
    private var recipeHeader: some View {
        VStack(alignment: .leading, spacing: UI.RecipeDetails.headerSpacing) {
            Text(viewModel.recipe.title)
                .font(UI.Fonts.largeTitle)
                .foregroundStyle(theme.text1)
                .accessibilityIdentifier(AccessibilityID.RecipeDetails.title)
            if let tagline = viewModel.recipe.tagline {
                Text(tagline)
                    .font(UI.Fonts.tagline)
                    .foregroundStyle(theme.text2)
            }
            HStack(spacing: UI.RecipeDetails.ratingSpacing) {
                if let rating = viewModel.recipe.apiRating ?? viewModel.recipe.userRating {
                    StarRating(rating: rating)
                    Text(String(format: "%.1f", rating))
                        .font(UI.Fonts.captionBold)
                        .foregroundStyle(theme.gold)
                }
                if let author = viewModel.recipe.author {
                    Text(String(format: Strings.RecipeDetails.byAuthor, author))
                        .font(UI.Fonts.caption)
                        .foregroundStyle(theme.text2)
                }
            }
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    /// Horizontal row of stat pills (cook time, calories, difficulty, servings, etc.).
    private var statsRow: some View {
        let infos = viewModel.recipe.additionalInfo.infos.filter(\.isNotEmpty)
        if !infos.isEmpty {
            HStack(spacing: UI.RecipeDetails.statsSpacing) {
                ForEach(infos, id: \.title) { info in
                    StatPill(
                        icon: statIcon(for: info),
                        value: info.stringValue,
                        label: info.title,
                        color: statColor(for: info)
                    )
                }
            }
            .padding(UI.RecipeDetails.statsPadding)
            .frostCard()
        }
    }

    // MARK: - Ingredients

    /// List of recipe ingredients, each with an availability dot, name, and quantity.
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: UI.RecipeDetails.ingredientsHeaderSpacing) {
            Text(Strings.RecipeDetails.sectionIngredients)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recipe.ingredients.indices), id: \.self) { i in
                    ingredientRow(at: i)
                }
            }
            .frostCard(cornerRadius: UI.RecipeDetails.cardCornerRadius)

            if viewModel.canShowAddToShoppingList {
                addToShoppingListButton
            }
        }
        .accessibilityIdentifier(AccessibilityID.RecipeDetails.ingredientsSection)
    }

    /// "Add Missing to List" button shown when there are missing ingredients and the user has premium.
    private var addToShoppingListButton: some View {
        Button {
            Task { await viewModel.addMissingToShoppingList() }
        } label: {
            HStack(spacing: UI.RecipeDetails.addToListSpacing) {
                Image(systemName: Icons.ShoppingList.cartBadgePlus)
                    .font(UI.Fonts.smallButtonIcon)
                Text(String(format: Strings.ShoppingList.addMissingToList, viewModel.missingIngredientNames.count))
                    .font(UI.Fonts.smallButton)
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, UI.RecipeDetails.addToListPaddingH)
            .padding(.vertical, UI.RecipeDetails.addToListPaddingV)
            .frame(maxWidth: .infinity)
            .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: UI.RecipeDetails.addToListCornerRadius, style: .continuous))
        }
        .accessibilityIdentifier(AccessibilityID.RecipeDetails.addToShoppingList)
    }

    /// A single ingredient row with a status dot, ingredient name, and optional quantity.
    private func ingredientRow(at index: Int) -> some View {
        let ingredient = viewModel.recipe.ingredients[index]
        let status = viewModel.ingredientStatus(ingredient)
        return VStack(spacing: 0) {
            HStack(spacing: UI.RecipeDetails.ingredientItemSpacing) {
                Circle()
                    .fill(ingredientDotColor(for: status))
                    .frame(width: UI.RecipeDetails.ingredientDotSize, height: UI.RecipeDetails.ingredientDotSize)
                    .accessibilityLabel(ingredientDotAccessibilityLabel(for: status))
                Text(ingredient.name.capitalized)
                    .font(UI.Fonts.bodyScaled)
                    .foregroundStyle(theme.text1)
                Spacer()
            }
            .padding(.vertical, UI.RecipeDetails.ingredientVerticalPadding)
            .padding(.horizontal, UI.RecipeDetails.ingredientHorizontalPadding)

            if index < viewModel.recipe.ingredients.count - 1 {
                Divider()
                    .background(theme.divider)
                    .padding(.leading, UI.RecipeDetails.ingredientDividerLeadingPadding)
            }
        }
    }

    /// Returns the dot color for an ingredient row: mint for available, rose for missing, divider for unknown.
    private func ingredientDotColor(for status: RecipeDetailsViewModel.IngredientStatus) -> Color {
        switch status {
        case .available: return theme.mint
        case .missing: return theme.rose
        case .unknown: return theme.accent.opacity(UI.RecipeDetails.ingredientDotOpacity)
        }
    }

    /// Returns the VoiceOver accessibility label for an ingredient status dot.
    private func ingredientDotAccessibilityLabel(for status: RecipeDetailsViewModel.IngredientStatus) -> String {
        switch status {
        case .available: return Strings.RecipeDetails.youHave
        case .missing: return Strings.RecipeDetails.youNeed
        case .unknown: return ""
        }
    }

    // MARK: - Steps

    /// Numbered list of recipe steps.
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: UI.RecipeDetails.stepsHeaderSpacing) {
            Text(Strings.RecipeDetails.sectionSteps)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: UI.RecipeDetails.stepsSpacing) {
                ForEach(Array(viewModel.recipe.instructions.enumerated()), id: \.offset) { index, step in
                    stepCard(index: index, step: step)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.RecipeDetails.stepsSection)
    }

    /// A card for a single cooking step with numbered badge and instruction text.
    private func stepCard(index: Int, step: Recipe.Step) -> some View {
        HStack(alignment: .top, spacing: UI.RecipeDetails.stepItemSpacing) {
            Text("\(index + 1)")
                .font(UI.Fonts.stepNumber)
                .foregroundStyle(theme.onAccent)
                .frame(width: UI.RecipeDetails.stepNumberSize, height: UI.RecipeDetails.stepNumberSize)
                .background(
                    LinearGradient(colors: [theme.accent, theme.rose],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: UI.Common.smallSpacing) {
                Text(step.text)
                    .font(UI.Fonts.bodyScaled)
                    .foregroundStyle(theme.text1)
                    .fixedSize(horizontal: false, vertical: true)

                if let timer = step.timerMinutes {
                    HStack(spacing: UI.Common.smallSpacing) {
                        Image(systemName: Icons.CookMode.timer)
                            .font(UI.Fonts.tinyCaption)
                        Text(String(format: Strings.Common.minutesShort, Int64(timer)))
                            .font(UI.Fonts.smallCaptionSemibold)
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, UI.RecipeDetails.stepTimerHorizontalPadding)
                    .padding(.vertical, UI.RecipeDetails.stepTimerVerticalPadding)
                    .background(theme.accentSoft, in: Capsule())
                }
            }

            Spacer()
        }
        .padding(UI.RecipeDetails.stepPadding)
        .frostCard(cornerRadius: UI.RecipeDetails.stepCornerRadius)
    }

    // MARK: - Start Cooking Button

    @ViewBuilder
    /// Sticky "Start Cooking" CTA pinned to the bottom of the screen.
    private var startCookingButton: some View {
        Button {
            viewModel.startCooking()
        } label: {
            HStack(spacing: UI.RecipeDetails.buttonSpacing) {
                Image(systemName: Icons.CookMode.play)
                    .font(UI.Fonts.buttonIcon)
                Text(Strings.CookMode.startCooking)
                    .font(UI.Fonts.buttonLabel)
            }
            .foregroundStyle(theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, UI.RecipeDetails.buttonVerticalPadding)
            .background(
                LinearGradient(colors: [theme.accent, theme.rose], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: UI.RecipeDetails.buttonCornerRadius, style: .continuous)
            )
            .neonGlow(theme.accent, radius: UI.Common.neonRadiusDefault)
        }
        .padding(.horizontal, UI.RecipeDetails.topBarHorizontalPadding)
        .padding(.bottom, UI.RecipeDetails.buttonBottomPadding)
        .background(alignment: .bottom) {
            LinearGradient(colors: [theme.bg, theme.bg.opacity(0)],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: UI.RecipeDetails.gradientHeight)
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier(AccessibilityID.RecipeDetails.startCookingButton)
    }

    // MARK: - Helpers

    /// Returns the SF Symbol name for a given `AdditionalInfo.InfoType` stat.
    private func statIcon(for info: Recipe.AdditionalInfo.InfoType) -> String {
        switch info {
        case .time: return Icons.Discover.clock
        case .servings: return Icons.Discover.person2
        case .calories: return Icons.Discover.flame
        case .complexity: return Icons.Discover.chartBar
        case .empty: return ""
        }
    }

    /// Returns the theme color for a given `AdditionalInfo.InfoType` stat icon.
    private func statColor(for info: Recipe.AdditionalInfo.InfoType) -> Color {
        switch info {
        case .time: return theme.accent
        case .servings: return theme.mint
        case .calories: return theme.rose
        case .complexity: return theme.lavender
        case .empty: return theme.text3
        }
    }
}

/// View-only helpers for presenting additional-info values in recipe details cards.
extension Recipe.AdditionalInfo.InfoType {
    /// Returns an icon-prefixed title/value tuple used by details info cells.
    var asTuple:(title: String, value: String) {
        (title:self.asEmoji + UI.RecipeDetails.infoTitleSeparator + self.title, value: stringValue)
    }
    
    /// `true` when the info case carries meaningful data.
    var isNotEmpty: Bool {
        self != .empty
    }
}
