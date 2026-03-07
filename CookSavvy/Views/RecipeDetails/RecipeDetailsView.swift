import SwiftUI

struct RecipeDetailsView: View {
    @ObservedObject var viewModel: RecipeDetailsViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        RecipeImage(recipe: viewModel.recipe, height: UI.V2.heroImageHeight)

                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: Icons.Common.backButton)
                                    .font(UI.Fonts.buttonIcon)
                                    .foregroundStyle(.white)
                                    .frame(width: UI.Common.backButtonSize, height: UI.Common.backButtonSize)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            Spacer()
                            Button {
                                Task { await viewModel.toggleFavorite() }
                            } label: {
                                Image(systemName: viewModel.isFavorite ? Icons.Discover.bookmarkFill : Icons.Discover.bookmark)
                                    .font(UI.Fonts.buttonIcon)
                                    .foregroundStyle(viewModel.isFavorite ? theme.accent : .white)
                                    .frame(width: UI.Common.backButtonSize, height: UI.Common.backButtonSize)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .disabled(viewModel.isLoadingFavorite)
                        }
                        .padding(.horizontal, UI.RecipeDetails.topBarHorizontalPadding)
                        .padding(.top, UI.V2.floatingButtonTopPadding)
                    }

                    ZStack(alignment: .topTrailing) {
                        VStack(alignment: .leading, spacing: UI.RecipeDetails.sectionSpacing) {
                            VStack(alignment: .leading, spacing: UI.RecipeDetails.headerSpacing) {
                                Text(viewModel.recipe.title)
                                    .font(UI.Fonts.largeTitle)
                                    .foregroundStyle(theme.text1)
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
                                        Text("by \(author)")
                                            .font(UI.Fonts.caption)
                                            .foregroundStyle(theme.text3)
                                    }
                                }
                            }

                            statsRow

                            ingredientsSection

                            stepsSection

                            Spacer(minLength: UI.Common.bottomSpacerMinLength)
                        }
                        .padding(UI.RecipeDetails.contentPadding)
                        .background(theme.bg)
                        .clipShape(.rect(topLeadingRadius: UI.RecipeDetails.contentTopCornerRadius, topTrailingRadius: UI.RecipeDetails.contentTopCornerRadius))
                        .offset(y: -UI.V2.contentOverlapOffset)

                        if let source = RecipeDisplaySource(recipe: viewModel.recipe) {
                            RecipeSourceBadge(source: source, cornerRadius: UI.RecipeDetails.contentTopCornerRadius)
                                .offset(y: -UI.V2.contentOverlapOffset)
                        }
                    }
                }
            }

            startCookingButton
        }
        .background(theme.bg)
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: UI.RecipeDetails.statsSpacing) {
            ForEach(viewModel.recipe.additionalInfo.infos.filter(\.isNotEmpty), id: \.title) { info in
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

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: UI.RecipeDetails.ingredientsHeaderSpacing) {
            Text("INGREDIENTS")
                .sectionLabel()

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recipe.ingredients.indices), id: \.self) { i in
                    HStack(spacing: UI.RecipeDetails.ingredientItemSpacing) {
                        Circle()
                            .fill(theme.accent.opacity(UI.RecipeDetails.ingredientDotOpacity))
                            .frame(width: UI.RecipeDetails.ingredientDotSize, height: UI.RecipeDetails.ingredientDotSize)
                        Text(viewModel.recipe.ingredients[i].name)
                            .font(UI.Fonts.body)
                            .foregroundStyle(theme.text1)
                        Spacer()
                    }
                    .padding(.vertical, UI.RecipeDetails.ingredientVerticalPadding)
                    .padding(.horizontal, UI.RecipeDetails.ingredientHorizontalPadding)

                    if i < viewModel.recipe.ingredients.count - 1 {
                        Divider()
                            .background(theme.divider)
                            .padding(.leading, UI.RecipeDetails.ingredientDividerLeadingPadding)
                    }
                }
            }
            .frostCard(cornerRadius: UI.RecipeDetails.cardCornerRadius)
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: UI.RecipeDetails.stepsHeaderSpacing) {
            Text("STEPS")
                .sectionLabel()

            VStack(spacing: UI.RecipeDetails.stepsSpacing) {
                ForEach(Array(viewModel.recipe.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: UI.RecipeDetails.stepItemSpacing) {
                        Text("\(index + 1)")
                            .font(UI.Fonts.stepNumber)
                            .foregroundStyle(.white)
                            .frame(width: UI.RecipeDetails.stepNumberSize, height: UI.RecipeDetails.stepNumberSize)
                            .background(
                                LinearGradient(colors: [theme.accent, theme.rose],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )

                        VStack(alignment: .leading, spacing: UI.Common.smallSpacing) {
                            Text(step.text)
                                .font(UI.Fonts.body)
                                .foregroundStyle(theme.text1)
                                .fixedSize(horizontal: false, vertical: true)

                            if let timer = step.timerMinutes {
                                HStack(spacing: UI.Common.smallSpacing) {
                                    Image(systemName: Icons.CookMode.timer)
                                        .font(UI.Fonts.tinyCaption)
                                    Text("\(timer) min")
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
            }
        }
    }

    // MARK: - Start Cooking Button

    @ViewBuilder
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
            .foregroundStyle(.white)
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
        .background(
            LinearGradient(colors: [theme.bg, theme.bg.opacity(0)],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: UI.RecipeDetails.gradientHeight)
                .allowsHitTesting(false)
        , alignment: .bottom)
    }

    // MARK: - Helpers

    private func statIcon(for info: Recipe.AdditionalInfo.InfoType) -> String {
        switch info {
        case .time: return Icons.Discover.clock
        case .servings: return Icons.Discover.person2
        case .calories: return Icons.Discover.flame
        case .complexity: return Icons.Discover.chartBar
        case .empty: return ""
        }
    }

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

extension Recipe.AdditionalInfo.InfoType {
    var asTuple:(title: String, value: String) {
        (title:self.asEmoji + UI.RecipeDetails.infoTitleSeparator + self.title, value: stringValue)
    }
    
    var isNotEmpty: Bool {
        self != .empty
    }
}
