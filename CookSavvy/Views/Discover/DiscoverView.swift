import SwiftUI

struct DiscoverView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: DiscoverViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.hasIngredients {
                resultsState
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ingredientSelectionState
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(theme.bg)
        .animation(UI.Anim.springSmooth, value: viewModel.hasIngredients)
        .task {
            await viewModel.loadInitialData()
        }
    }

    // MARK: - State 1: Ingredient Selection

    private var ingredientSelectionState: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: UI.Discover.sectionSpacing) {
                    headerView
                    searchBar
                    recentSection
                    savedSection
                    categoryFilter
                    ingredientGrid
                    Spacer(minLength: UI.Discover.bottomSpacerMinLength)
                }
                .padding(.horizontal, UI.Discover.horizontalPadding)
            }
        }
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
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(UI.Fonts.searchField)
                        .foregroundStyle(theme.text3)
                }
            }
            Button {
                viewModel.showCamera()
            } label: {
                Image(systemName: "camera.fill")
                    .font(UI.Fonts.iconMedium)
                    .foregroundStyle(theme.accent)
            }
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
                            Button {
                                viewModel.showRecipeDetails(recipe)
                            } label: {
                                MiniRecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        if !viewModel.savedRecipes.isEmpty {
            VStack(alignment: .leading, spacing: UI.Discover.sectionContentSpacing) {
                HStack {
                    Text(Strings.Discover.savedSection)
                        .sectionLabel()
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
                            Button {
                                viewModel.showRecipeDetails(recipe)
                            } label: {
                                MiniRecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
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
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UI.Discover.categoryChipSpacing) {
                ForEach(IngredientCategory.allCases, id: \.self) { cat in
                    if cat != .other {
                        CategoryChip(category: cat, isSelected: viewModel.selectedCategory == cat)
                            .onTapGesture {
                                withAnimation(UI.Anim.easeQuick) {
                                    viewModel.toggleCategory(cat)
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

            if viewModel.isLoadingIngredients {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, UI.Discover.loadingPadding)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: UI.Discover.gridItemSpacing), count: UI.Discover.gridColumnCount), spacing: UI.Discover.gridSpacing) {
                    ForEach(viewModel.filteredIngredients) { ingredient in
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
    }

    // MARK: - State 2: Recipe Results

    private var resultsState: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: UI.Discover.sectionSpacing) {
                    resultsHeader
                    selectedIngredientsStrip
                    moodFilter
                    bestMatchSection
                    moreRecipesSection
                    Spacer(minLength: UI.Discover.bottomSpacerMinLength)
                }
                .padding(.horizontal, UI.Discover.horizontalPadding)
            }
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
                Text("🧑‍🍳")
                    .font(.system(size: UI.Journey.statIconSize))
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Discover.categoryChipSpacing) {
                    ForEach(viewModel.selectedIngredients) { ing in
                        SelectedChip(ingredient: ing) {
                            withAnimation(UI.Anim.springQuick) {
                                viewModel.removeIngredient(ing)
                            }
                        }
                    }

                    Button {
                        withAnimation(UI.Anim.springClear) {
                            viewModel.clearIngredients()
                        }
                    } label: {
                        Image(systemName: Icons.Discover.plus)
                            .font(UI.Fonts.smallButtonIcon)
                            .foregroundStyle(theme.accent)
                            .frame(width: UI.Discover.addButtonSize, height: UI.Discover.addButtonSize)
                            .background(theme.accentSoft, in: Circle())
                    }
                }
            }
        }
    }

    private var moodFilter: some View {
        VStack(alignment: .leading, spacing: UI.Discover.moodPillSpacing) {
            Text(Strings.MoodFilter.refineByMood)
                .sectionLabel()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UI.Discover.moodPillSpacing) {
                    ForEach(DiscoverViewModel.moods) { mood in
                        MoodPill(
                            name: mood.name,
                            icon: mood.icon,
                            color: mood.color,
                            gradient: mood.gradient,
                            isSelected: viewModel.selectedMood == mood.id
                        )
                        .onTapGesture {
                            withAnimation(UI.Anim.springBouncy) {
                                viewModel.toggleMood(mood.id)
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

                Button {
                    viewModel.showRecipeDetails(featured)
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        RecipeImage(recipe: featured, height: UI.Discover.recipeImageHeight)
                            .clipShape(RoundedRectangle(cornerRadius: UI.Discover.recipeCardCornerRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: UI.Discover.featuredInfoSpacing) {
                            if let match = featured.matchPercentage {
                                HStack(spacing: UI.Discover.matchBadgeSpacing) {
                                    Image(systemName: Icons.Discover.matchBadge)
                                        .font(UI.Fonts.tinyCaption)
                                    Text("\(Int(match))% match")
                                        .font(UI.Fonts.smallCaptionBold)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, UI.Discover.matchBadgePaddingH)
                                .padding(.vertical, UI.Discover.matchBadgePaddingV)
                                .background(theme.mint.opacity(UI.RecipeDetails.matchBadgeOpacity), in: Capsule())
                            }

                            Text(featured.title)
                                .font(UI.Fonts.title)
                                .foregroundStyle(.white)

                            HStack(spacing: UI.Discover.featuredLabelSpacing) {
                                if let time = cookTimeLabel(featured) {
                                    Label(time, systemImage: Icons.Discover.clock)
                                }
                                if let complexity = complexityLabel(featured) {
                                    Label(complexity, systemImage: Icons.Discover.chartBar)
                                }
                                if let rating = featured.apiRating ?? featured.userRating {
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
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var moreRecipesSection: some View {
        if !viewModel.moreRecipes.isEmpty {
            VStack(alignment: .leading, spacing: UI.Discover.moreRecipesSpacing) {
                HStack {
                    Text(Strings.Discover.moreRecipes)
                        .sectionLabel()
                    Spacer()
                    Text("\(viewModel.filteredRecipes.count) found")
                        .font(UI.Fonts.captionSemibold)
                        .foregroundStyle(theme.text2)
                }

                ForEach(viewModel.moreRecipes) { recipe in
                    Button {
                        viewModel.showRecipeDetails(recipe)
                    } label: {
                        RecipeRow(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func cookTimeLabel(_ recipe: Recipe) -> String? {
        for info in recipe.additionalInfo.infos {
            if case .time(let t) = info { return t }
        }
        return nil
    }

    private func complexityLabel(_ recipe: Recipe) -> String? {
        for info in recipe.additionalInfo.infos {
            if case .complexity(let c) = info { return c }
        }
        return nil
    }
}
