import SwiftUI

struct DiscoverView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject var viewModel: DiscoverViewModel
    @State private var isMatchInfoPopoverPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.showResults {
                resultsState
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            } else {
                ingredientSelectionState
                    .transition(reduceMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(theme.bg)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : UI.Anim.springSmooth, value: viewModel.showResults)
        .task {
            await viewModel.loadInitialData()
        }
        .onAppear {
            viewModel.refreshDietaryRestrictions()
        }
    }

    // MARK: - State 1: Ingredient Selection

    private var ingredientSelectionState: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: UI.Discover.sectionSpacing) {
                        headerView
                        searchBar
                        selectedIngredientsStrip
                        recentSection
                        savedSection
                        suggestedSection
                        collectionsSection
                        if viewModel.isDiscoverEmpty {
                            discoverEmptyState
                        }
                        categoryFilter
                        ingredientGrid
                        Spacer(minLength: UI.Discover.bottomSpacerMinLength + UI.Discover.findButtonHeight)
                    }
                    .padding(.horizontal, UI.Discover.horizontalPadding)
                }
            }
            
            if viewModel.hasIngredients {
                searchButton
            }
        }
    }
    
    private var searchButton: some View {
        Button {
            withAnimation(UI.Anim.springNav) {
                viewModel.findRecipes()
            }
        } label: {
            Text(Strings.Discover.findRecipes)
                .font(UI.Fonts.buttonLabel)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: UI.Discover.findButtonHeight)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: UI.Discover.findButtonCornerRadius, style: .continuous))
                .neonGlow(theme.accent, radius: UI.Common.neonRadiusDefault)
        }
        .padding(.horizontal, UI.Discover.horizontalPadding)
        .padding(.bottom, UI.Discover.findButtonBottomPadding)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier(AccessibilityID.Discover.findRecipesButton)
    }

    private var cameraButton: some View {
        Button {
            viewModel.showCamera()
        } label: {
            ZStack(alignment: .topTrailing) {
                cameraIcon
                if viewModel.showScansBadge {
                    Text("\(viewModel.remainingCameraScans)")
                        .font(.system(size: UI.Discover.cameraBadgeFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, UI.Discover.cameraBadgePaddingH)
                        .padding(.vertical, UI.Discover.cameraBadgePaddingV)
                        .background(viewModel.remainingCameraScans > 0 ? theme.mint : theme.rose, in: Capsule())
                        .offset(x: UI.Discover.cameraBadgeOffsetX, y: UI.Discover.cameraBadgeOffsetY)
                        .accessibilityIdentifier(AccessibilityID.Camera.scanLimitBadge)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Discover.cameraButton)
        .accessibilityLabel(Strings.Accessibility.scanCamera)
    }

    private var cameraIcon: some View {
        Image(systemName: Icons.Camera.camera)
            .font(UI.Fonts.iconMedium)
            .foregroundStyle(theme.accent)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: UI.Discover.headerSpacing) {
            Text(viewModel.greeting)
                .font(UI.Fonts.greeting)
                .foregroundStyle(theme.text3)
            Text(Strings.Discover.kitchenTitle)
                .font(UI.Fonts.heroTitle)
                .foregroundStyle(theme.text1)
            Text(Strings.Discover.kitchenSubtitle)
                .font(UI.Fonts.body)
                .foregroundStyle(theme.text2)
        }
        .padding(.top, UI.Discover.headerTopPadding)
    }

    private var searchBar: some View {
        HStack(spacing: UI.Discover.searchBarSpacing) {
            Image(systemName: Icons.SearchBar.magnifying)
                .font(UI.Fonts.iconMedium)
                .foregroundStyle(theme.text3)
            TextField(Strings.Discover.searchPlaceholder, text: $viewModel.searchText)
                .font(UI.Fonts.searchField)
                .foregroundStyle(theme.text1)
                .accessibilityIdentifier(AccessibilityID.Discover.searchField)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: Icons.SearchBar.clear)
                        .font(UI.Fonts.searchField)
                        .foregroundStyle(theme.text3)
                }
                .accessibilityLabel(Strings.Accessibility.clearSearch)
            }
            cameraButton
        }
        .padding(.horizontal, UI.Discover.searchBarHorizontalPadding)
        .padding(.vertical, UI.Discover.searchBarVerticalPadding)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: UI.Discover.searchBarCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UI.Discover.searchBarCornerRadius, style: .continuous)
                .strokeBorder(theme.divider, lineWidth: UI.Common.borderWidth)
        )
    }

    @ViewBuilder
    private var recentSection: some View {
        if !viewModel.recentRecipes.isEmpty {
            VStack(alignment: .leading, spacing: UI.Discover.sectionContentSpacing) {
                HStack {
                    Text(Strings.Discover.recentSection)
                        .sectionLabel()
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button {
                        viewModel.showRecipeList(
                            title: Strings.RecipeList.recentRecipes,
                            recipes: viewModel.recentRecipes
                        )
                    } label: {
                        Text(Strings.Discover.seeAll)
                            .font(UI.Fonts.captionSemibold)
                            .foregroundStyle(theme.accent)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UI.Discover.sectionContentSpacing) {
                        ForEach(viewModel.recentRecipes) { recipe in
                            MiniRecipeCard(recipe: recipe)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.showRecipeDetails(recipe)
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier(AccessibilityID.Discover.recipe(recipe.title))
                        }
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Discover.recentSection)
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        if !viewModel.savedRecipes.isEmpty {
            VStack(alignment: .leading, spacing: UI.Discover.sectionContentSpacing) {
                HStack {
                    Text(Strings.Discover.savedSection)
                        .sectionLabel()
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button {
                        viewModel.showRecipeList(
                            title: Strings.RecipeList.savedRecipes,
                            recipes: viewModel.savedRecipes
                        )
                    } label: {
                        Text(Strings.Discover.seeAll)
                            .font(UI.Fonts.captionSemibold)
                            .foregroundStyle(theme.accent)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UI.Discover.sectionContentSpacing) {
                        ForEach(viewModel.savedRecipes) { recipe in
                            MiniRecipeCard(recipe: recipe)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.showRecipeDetails(recipe)
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier(AccessibilityID.Discover.recipe(recipe.title))
                        }

                        Button {
                            viewModel.showCreateRecipe()
                        } label: {
                            AddYourOwnCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Discover.savedSection)
        }
    }

    @ViewBuilder
    private var suggestedSection: some View {
        if !viewModel.suggestedRecipes.isEmpty {
            VStack(alignment: .leading, spacing: UI.Discover.sectionContentSpacing) {
                VStack(alignment: .leading, spacing: UI.Common.smallSpacing) {
                    Text(Strings.Discover.suggestedForYou)
                        .sectionLabel()
                        .accessibilityAddTraits(.isHeader)
                    if let reason = viewModel.suggestionReason {
                        Text(reason)
                            .font(UI.Fonts.caption)
                            .foregroundStyle(theme.text3)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UI.Discover.sectionContentSpacing) {
                        ForEach(viewModel.suggestedRecipes) { recipe in
                            MiniRecipeCard(recipe: recipe)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.showRecipeDetails(recipe)
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier(AccessibilityID.Discover.recipe(recipe.title))
                        }
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Discover.suggestedSection)
        }
    }

    @ViewBuilder
    private var collectionsSection: some View {
        if !viewModel.collections.isEmpty {
            VStack(alignment: .leading, spacing: UI.Discover.sectionContentSpacing) {
                Text(Strings.Discover.collectionsSection)
                    .sectionLabel()
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UI.Discover.sectionContentSpacing) {
                        ForEach(viewModel.collections) { collection in
                            CollectionCard(
                                collection: collection,
                                isLoading: viewModel.loadingCollectionID == collection.id
                            )
                            .onTapGesture {
                                viewModel.showCollection(collection)
                            }
                        }
                    }
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UI.Discover.categoryChipSpacing) {
                ForEach(IngredientCategory.allCases, id: \.self) { category in
                    if category != .other {
                        CategoryChip(category: category, isSelected: viewModel.selectedCategory == category)
                            .onTapGesture {
                                withAnimation(UI.Anim.easeQuick) {
                                    viewModel.toggleCategory(category)
                                }
                            }
                    }
                }
            }
        }
    }

    private var ingredientGrid: some View {
        VStack(alignment: .leading, spacing: UI.Discover.ingredientGridHeaderSpacing) {
            Text(viewModel.ingredientGridLabel)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            if viewModel.isLoadingIngredients {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, UI.Discover.loadingPadding)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: UI.Discover.gridItemSpacing), count: UI.Discover.gridColumnCount), spacing: UI.Discover.gridSpacing) {
                    ForEach(viewModel.shownIngredients) { ingredient in
                        IngredientBubble(
                            ingredient: ingredient,
                            isSelected: viewModel.selectedIngredients.contains(where: { $0.id == ingredient.id })
                        )
                        .onTapGesture {
                            withAnimation(UI.Anim.springQuick) {
                                viewModel.toggleIngredient(ingredient)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Discover.ingredientGrid)
    }

    private var discoverEmptyState: some View {
        VStack(spacing: UI.ShoppingList.emptyStateSpacing) {
            Image(systemName: Icons.Discover.emptyState)
                .font(.system(size: UI.ShoppingList.emptyIconSize))
                .foregroundStyle(theme.text3)
            Text(Strings.Discover.emptyStateTitle)
                .font(UI.Fonts.title)
                .foregroundStyle(theme.text1)
            Text(Strings.Discover.emptyStateSubtitle)
                .font(UI.Fonts.body)
                .foregroundStyle(theme.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UI.Discover.loadingPadding)
        .accessibilityIdentifier(AccessibilityID.Discover.emptyState)
    }

    private var noResultsState: some View {
        VStack(spacing: UI.ShoppingList.emptyStateSpacing) {
            Image(systemName: Icons.Discover.noResults)
                .font(.system(size: UI.ShoppingList.emptyIconSize))
                .foregroundStyle(theme.text3)
            Text(Strings.Discover.noResultsTitle)
                .font(UI.Fonts.title)
                .foregroundStyle(theme.text1)
            Text(Strings.Discover.noResultsSubtitle)
                .font(UI.Fonts.body)
                .foregroundStyle(theme.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UI.Discover.loadingPadding)
        .accessibilityIdentifier(AccessibilityID.Discover.noResultsState)
    }

    // MARK: - State 2: Recipe Results

    private var useItAllToggle: some View {
        Button {
            withAnimation(UI.Anim.springBouncy) {
                viewModel.useItAllFilter.toggle()
            }
        } label: {
            Label(Strings.Discover.useItAll, systemImage: Icons.Discover.useItAll)
                .font(UI.Fonts.captionSemibold)
                .foregroundStyle(viewModel.useItAllFilter ? .white : theme.text2)
                .padding(.horizontal, UI.Discover.useItAllPaddingH)
                .padding(.vertical, UI.Discover.useItAllPaddingV)
                .background(viewModel.useItAllFilter ? theme.mint : theme.surface, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(theme.divider, lineWidth: UI.Common.borderWidth)
                        .opacity(viewModel.useItAllFilter ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.Discover.useItAllToggle)
        .accessibilityLabel(viewModel.useItAllFilter ? Strings.Accessibility.useItAllActive : Strings.Accessibility.useItAllInactive)
    }

    private var resultsState: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: UI.Discover.sectionSpacing) {
                resultsHeader
                selectedIngredientsStrip
                moodFilter
                useItAllToggle
                dietaryFilterPills
                if viewModel.searchError != nil {
                    errorBanner
                }
                if viewModel.hasNoResults {
                    noResultsState
                } else {
                    bestMatchSection
                    moreRecipesSection
                }
            }
            .padding(.horizontal, UI.Discover.horizontalPadding)
            .padding(.bottom, UI.Discover.findButtonBottomPadding)
        }
    }

    @ViewBuilder
    private var dietaryFilterPills: some View {
        if !viewModel.activeDietaryRestrictions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Discover.categoryChipSpacing) {
                    ForEach(Array(viewModel.activeDietaryRestrictions), id: \.self) { restriction in
                        Button {
                            withAnimation(UI.Anim.springQuick) {
                                viewModel.removeDietaryRestriction(restriction)
                            }
                        } label: {
                            Label(restriction.displayName, systemImage: restriction.icon)
                                .font(UI.Fonts.captionSemibold)
                                .foregroundStyle(theme.mint)
                                .padding(.horizontal, UI.Discover.useItAllPaddingH)
                                .padding(.vertical, UI.Discover.useItAllPaddingV)
                                .background(theme.mintSoft, in: Capsule())
                                .overlay(
                                    Capsule().strokeBorder(theme.mint.opacity(0.3), lineWidth: UI.Common.borderWidth)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(format: Strings.Accessibility.removeDietaryRestriction, restriction.displayName))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = viewModel.searchError {
            HStack(spacing: UI.Common.smallSpacing) {
                Image(systemName: Icons.Discover.error)
                    .foregroundStyle(theme.gold)
                Text(errorMessage)
                    .font(UI.Fonts.caption)
                    .foregroundStyle(theme.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    viewModel.retrySearch()
                } label: {
                    Text(Strings.Discover.retry)
                        .font(UI.Fonts.captionSemibold)
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(UI.Common.horizontalPadding)
            .frostCard()
        }
    }

    private var resultsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: UI.Discover.resultsHeaderSpacing) {
                Text(viewModel.greeting)
                    .font(UI.Fonts.greeting)
                    .foregroundStyle(theme.text3)
                Text(Strings.Discover.recipesForYou)
                    .font(UI.Fonts.largeTitle)
                    .foregroundStyle(theme.text1)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [theme.accent, theme.rose],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: UI.Common.backButtonSize, height: UI.Common.backButtonSize)
                Text(UI.Discover.chefEmoji)
                    .font(.system(size: UI.Discover.chefEmojiSize))
            }
        }
        .padding(.top, UI.Discover.headerTopPadding)
    }

    private var selectedIngredientsStrip: some View {
        VStack(alignment: .leading, spacing: UI.Discover.ingredientStripSpacing) {
            HStack {
                Text(Strings.Discover.yourIngredients)
                    .sectionLabel()
                Spacer()
                if viewModel.showResults {
                    Button {
                        withAnimation(UI.Anim.springClear) {
                            viewModel.clearIngredients()
                        }
                    } label: {
                        Text(Strings.Discover.edit)
                            .font(UI.Fonts.captionSemibold)
                            .foregroundStyle(theme.accent)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Discover.categoryChipSpacing) {
                    ForEach(viewModel.selectedIngredients) { ingredient in
                        SelectedChip(ingredient: ingredient) {
                            withAnimation(UI.Anim.springQuick) {
                                viewModel.removeIngredient(ingredient)
                            }
                        }
                    }
                    if viewModel.showResults {
                        Button {
                            withAnimation(UI.Anim.springClear) {
                                viewModel.showResults = false
                            }
                        } label: {
                            Image(systemName: Icons.Discover.plus)
                                .font(UI.Fonts.smallButtonIcon)
                                .foregroundStyle(theme.accent)
                                .frame(width: UI.Discover.addButtonSize, height: UI.Discover.addButtonSize)
                                .background(theme.accentSoft, in: Circle())
                        }
                        .accessibilityLabel(Strings.Accessibility.addMoreIngredients)
                    }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Discover.selectedStrip)
    }

    private var moodFilter: some View {
        VStack(alignment: .leading, spacing: UI.Discover.moodPillSpacing) {
            Text(Strings.MoodFilter.refineByMood)
                .sectionLabel()
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Discover.moodPillSpacing) {
                    ForEach(RecipeMood.allCases) { mood in
                        MoodPill(
                            name: mood.name,
                            icon: mood.icon,
                            color: UI.Discover.moodColor(for: mood),
                            gradient: UI.Discover.moodGradient(for: mood),
                            isSelected: viewModel.selectedMood == mood
                        )
                        .onTapGesture {
                            withAnimation(UI.Anim.springBouncy) {
                                viewModel.toggleMood(mood)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bestMatchSection: some View {
        if viewModel.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, UI.Discover.loadingPadding)
        } else if let featured = viewModel.bestMatch {
            VStack(alignment: .leading, spacing: UI.Discover.bestMatchSpacing) {
                Text(Strings.Discover.bestMatch)
                    .sectionLabel()
                    .accessibilityAddTraits(.isHeader)

                ZStack(alignment: .bottomLeading) {
                    RecipeImage(recipe: featured, height: UI.Discover.recipeImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: UI.Discover.recipeCardCornerRadius, style: .continuous))

                    featuredHeroOverlay(for: featured)
                }
                .contentShape(RoundedRectangle(cornerRadius: UI.Discover.recipeCardCornerRadius, style: .continuous))
                .gesture(
                    TapGesture().onEnded {
                        viewModel.showRecipeDetails(featured)
                    },
                    including: .gesture
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(AccessibilityID.Discover.recipe(featured.title))
            }
            .accessibilityIdentifier(AccessibilityID.Discover.bestMatch)
        }
    }

    private func featuredHeroOverlay(for recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: UI.Discover.featuredInfoSpacing) {
            if recipe.missingIngredients != nil || recipe.matchPercentage != nil {
                matchIndicator(recipe: recipe, matchingIngredients: viewModel.matchingIngredientNames(for: recipe))
            }
            if let reason = recipe.matchReason {
                Label(reason, systemImage: Icons.Discover.idea)
                    .font(UI.Fonts.tinyCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, UI.Discover.matchBadgePaddingH)
                    .padding(.vertical, UI.Discover.matchBadgePaddingV)
                    .background(.white.opacity(0.2), in: Capsule())
            }
            Text(recipe.title)
                .font(UI.Fonts.title)
                .foregroundStyle(.white)
            HStack(spacing: UI.Discover.featuredLabelSpacing) {
                if let time = cookTimeLabel(recipe) {
                    Label(time, systemImage: Icons.Discover.clock)
                }
                if let complexity = complexityLabel(recipe) {
                    Label(complexity, systemImage: Icons.Discover.chartBar)
                }
                if let rating = recipe.apiRating ?? recipe.userRating {
                    StarRating(rating: rating)
                }
            }
            .font(UI.Fonts.smallCaptionMedium)
            .foregroundStyle(.white.opacity(UI.Discover.whiteOpacity085))
        }
        .padding(UI.Discover.featuredInfoPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(UI.Discover.gradientOpacityTop), location: 0),
                    .init(color: .black.opacity(UI.Discover.gradientOpacityMid), location: 0.6),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .bottom, endPoint: .top
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: UI.Discover.recipeCardCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var moreRecipesSection: some View {
        if !viewModel.moreRecipes.isEmpty {
            VStack(alignment: .leading, spacing: UI.Discover.moreRecipesSpacing) {
                HStack {
                    Text(Strings.Discover.moreRecipes)
                        .sectionLabel()
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text(String(format: Strings.Discover.resultsFound, Int64(viewModel.filteredRecipes.count)))
                        .font(UI.Fonts.captionSemibold)
                        .foregroundStyle(theme.text2)
                }

                ForEach(viewModel.moreRecipes) { recipe in
                    RecipeRow(recipe: recipe)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.showRecipeDetails(recipe)
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier(AccessibilityID.Discover.recipe(recipe.title))
                }
            }
            .accessibilityIdentifier(AccessibilityID.Discover.moreRecipes)
        }
    }

    // MARK: - Helpers

    private func cookTimeLabel(_ recipe: Recipe) -> String? {
        for info in recipe.additionalInfo.infos {
            if case .time(let cookTime) = info { return cookTime }
        }
        return nil
    }

    private func complexityLabel(_ recipe: Recipe) -> String? {
        for info in recipe.additionalInfo.infos {
            if case .complexity(let complexity) = info { return complexity }
        }
        return nil
    }

    private func matchIndicator(recipe: Recipe, matchingIngredients: [String]) -> some View {
        let total = recipe.cleanedIngredients.isEmpty ? recipe.ingredients.count : recipe.cleanedIngredients.count
        let missing = recipe.missingIngredients?.count ?? 0
        let matched = max(0, total - missing)
        let label: String = recipe.missingIngredients?.isEmpty == true
            ? Strings.Discover.matchLabelAll
            : String(format: Strings.Discover.matchLabel, Int64(matched), Int64(total))

        return HStack(spacing: UI.Discover.matchBadgeSpacing) {
            Image(systemName: Icons.Discover.matchBadge)
                .font(UI.Fonts.tinyCaption)
            Text(label)
                .font(UI.Fonts.smallCaptionBold)
            Button {
                isMatchInfoPopoverPresented = true
            } label: {
                Image(systemName: Icons.Discover.matchInfo)
                    .font(UI.Fonts.tinyCaption)
                    .frame(width: UI.Discover.matchInfoButtonSize, height: UI.Discover.matchInfoButtonSize)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isMatchInfoPopoverPresented) {
                MatchDetailsPopover(ingredients: matchingIngredients)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, UI.Discover.matchBadgePaddingH)
        .padding(.vertical, UI.Discover.matchBadgePaddingV)
        .background(theme.mint.opacity(UI.RecipeDetails.matchBadgeOpacity), in: Capsule())
    }
}

private struct CollectionCard: View {
    @Environment(\.appTheme) private var theme
    let collection: CuratedCollection
    let isLoading: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [collection.gradientColors.0, collection.gradientColors.1],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: UI.Common.smallSpacing) {
                Text(collection.emoji)
                    .font(.system(size: UI.Discover.Collection.emojiFontSize))
                Spacer()
                Text(collection.title)
                    .font(UI.Fonts.captionBold)
                    .foregroundStyle(.white.opacity(UI.Discover.Collection.titleOpacity))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(collection.subtitle)
                    .font(UI.Fonts.tinyCaption)
                    .foregroundStyle(.white.opacity(UI.Discover.Collection.subtitleOpacity))
                    .lineLimit(1)
            }
            .padding(UI.Common.largeSpacing)

            if isLoading {
                Color.black.opacity(0.3)
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: UI.Discover.Collection.cardWidth, height: UI.Discover.Collection.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: UI.Discover.Collection.cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: UI.Discover.Collection.cornerRadius, style: .continuous))
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(collection.title)
    }
}

private struct MatchDetailsPopover: View {
    @Environment(\.appTheme) private var theme
    let ingredients: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: UI.Discover.matchPopoverSpacing) {
            Text(Strings.Discover.matchDetailsTitle)
                .font(UI.Fonts.smallCaptionBold)
                .foregroundStyle(theme.text1)
            Text(ingredients.isEmpty ? Strings.Discover.matchDetailsEmpty : ingredients.joined(separator: ", "))
                .font(UI.Fonts.smallCaption)
                .foregroundStyle(theme.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: UI.Discover.matchPopoverWidth, alignment: .leading)
        .padding(UI.Discover.matchPopoverPadding)
        .background(theme.surface)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(theme.surface)
    }
}
