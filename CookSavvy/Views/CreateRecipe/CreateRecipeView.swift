import SwiftUI

struct CreateRecipeView: View {
    @Environment(\.appTheme) private var theme
    @StateObject var viewModel: CreateRecipeViewModel

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                stepProgressDots

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch viewModel.currentStep {
                        case .nameAndPhoto: step1NameAndPhoto
                        case .ingredients: step2Ingredients
                        case .steps: step3Steps
                        case .details: step4Details
                        case .review: step5Review
                        }
                    }
                    .padding(.horizontal, UI.CreateRecipe.horizontalPadding)
                    .padding(.top, UI.CreateRecipe.topPadding)
                    .padding(.bottom, UI.CreateRecipe.bottomScrollPadding)
                }

                bottomButton
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Button {
                if viewModel.canGoBack {
                    withAnimation(UI.Anim.springDefault) { viewModel.goBack() }
                } else {
                    viewModel.dismiss()
                }
            } label: {
                if !viewModel.canGoBack {
                    Image(systemName: Icons.CreateRecipe.close)
                        .font(UI.Fonts.smallButtonIcon)
                        .foregroundStyle(theme.text2)
                        .frame(width: UI.CreateRecipe.headerButtonSize, height: UI.CreateRecipe.headerButtonSize)
                        .background(theme.surface, in: Circle())
                } else {
                    HStack(spacing: UI.Common.smallSpacing) {
                        Image(systemName: Icons.Common.backButton)
                            .font(UI.Fonts.smallCaptionBold)
                        Text(Strings.CreateRecipe.back)
                            .font(UI.Fonts.smallButton)
                    }
                    .foregroundStyle(theme.accent)
                }
            }

            Spacer()

            Text(viewModel.currentStep.title)
                .font(UI.Fonts.sectionTitle)
                .foregroundStyle(theme.text1)

            Spacer()

            Color.clear.frame(width: UI.CreateRecipe.headerButtonSize, height: UI.CreateRecipe.headerButtonSize)
        }
        .padding(.horizontal, UI.CreateRecipe.headerHorizontalPadding)
        .padding(.top, UI.CreateRecipe.headerTopPadding)
    }

    // MARK: - Step Progress Dots

    private var stepProgressDots: some View {
        HStack(spacing: UI.CookMode.dotsSpacing) {
            ForEach(CreateRecipeViewModel.WizardStep.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step == viewModel.currentStep ? theme.accent :
                            (step.rawValue < viewModel.currentStep.rawValue ? theme.mint : theme.surfaceLight))
                    .frame(height: UI.Common.dotHeight)
                    .frame(maxWidth: step == viewModel.currentStep ? .infinity : UI.Common.dotInactiveWidth)
                    .animation(UI.Anim.springDefault, value: viewModel.currentStep)
            }
        }
        .padding(.horizontal, UI.CreateRecipe.dotsPadding)
        .padding(.top, UI.CreateRecipe.dotsTopPadding)
    }

    // MARK: - Step 1: Name & Photo

    private var step1NameAndPhoto: some View {
        VStack(alignment: .leading, spacing: UI.CreateRecipe.sectionSpacing) {
            ZStack {
                LinearGradient(
                    colors: [theme.accent.opacity(UI.CreateRecipe.opacityHalf), theme.rose.opacity(UI.CreateRecipe.opacityLight)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Text(viewModel.selectedEmoji)
                    .font(.system(size: UI.CreateRecipe.photoEmojiSize))
                    .shadow(color: .black.opacity(UI.Components.emojiShadowOpacity), radius: UI.Components.emojiShadowRadius, y: UI.Components.emojiShadowY)
            }
            .frame(maxWidth: .infinity)
            .frame(height: UI.CreateRecipe.photoHeight)
            .clipShape(RoundedRectangle(cornerRadius: UI.CreateRecipe.photoCornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: UI.CreateRecipe.fieldSpacing) {
                Text("RECIPE NAME")
                    .sectionLabel()

                TextField(Strings.CreateRecipe.recipeName, text: $viewModel.recipeName)
                    .font(UI.Fonts.inputField)
                    .foregroundStyle(theme.text1)
                    .padding(UI.CreateRecipe.inputPadding)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: UI.CreateRecipe.inputCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: UI.CreateRecipe.inputCornerRadius, style: .continuous)
                            .strokeBorder(theme.divider, lineWidth: UI.Common.borderWidth)
                    )
            }

            VStack(alignment: .leading, spacing: UI.CreateRecipe.fieldSpacing) {
                Text("TAGLINE")
                    .sectionLabel()

                TextField(Strings.CreateRecipe.taglinePlaceholder, text: $viewModel.tagline)
                    .font(UI.Fonts.bodyRounded)
                    .foregroundStyle(theme.text1)
                    .padding(UI.CreateRecipe.inputPadding)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: UI.CreateRecipe.inputCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: UI.CreateRecipe.inputCornerRadius, style: .continuous)
                            .strokeBorder(theme.divider, lineWidth: UI.Common.borderWidth)
                    )
            }

            VStack(alignment: .leading, spacing: UI.CreateRecipe.fieldSpacing) {
                Text("CHOOSE AN ICON")
                    .sectionLabel()

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: UI.CreateRecipe.emojiGridSpacing), count: UI.CreateRecipe.emojiGridColumns), spacing: UI.CreateRecipe.emojiGridSpacing) {
                    ForEach(CreateRecipeViewModel.foodEmojis, id: \.self) { emoji in
                        EmojiPickerCell(
                            emoji: emoji,
                            isSelected: viewModel.selectedEmoji == emoji,
                            onTap: { viewModel.selectedEmoji = emoji }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Ingredients

    private var step2Ingredients: some View {
        VStack(alignment: .leading, spacing: UI.CreateRecipe.ingredientSpacing) {
            Text("INGREDIENTS")
                .sectionLabel()

            VStack(spacing: UI.CreateRecipe.ingredientRowSpacing) {
                ForEach(viewModel.ingredientRows.indices, id: \.self) { i in
                    HStack(spacing: UI.CreateRecipe.ingredientItemSpacing) {
                        Button {
                            withAnimation(UI.Anim.springQuick) {
                                viewModel.removeIngredientRow(at: i)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: UI.Journey.statIconSize))
                                .foregroundStyle(theme.rose.opacity(viewModel.ingredientRows.count > 1 ? 1 : UI.CreateRecipe.opacityLight))
                        }
                        .disabled(viewModel.ingredientRows.count <= 1)

                        TextField("Ingredient \(i + 1)", text: $viewModel.ingredientRows[i])
                            .font(UI.Fonts.bodyRounded)
                            .foregroundStyle(theme.text1)
                            .padding(UI.CreateRecipe.ingredientInputPadding)
                            .background(theme.surface, in: RoundedRectangle(cornerRadius: UI.CreateRecipe.ingredientInputCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: UI.CreateRecipe.ingredientInputCornerRadius, style: .continuous)
                                    .strokeBorder(theme.divider, lineWidth: UI.Common.borderWidth)
                            )
                    }
                }
            }

            Button {
                withAnimation(UI.Anim.springQuick) {
                    viewModel.addIngredientRow()
                }
            } label: {
                HStack(spacing: UI.CreateRecipe.addButtonSpacing) {
                    Image(systemName: "plus.circle.fill")
                        .font(UI.Fonts.iconMedium)
                    Text("Add Ingredient")
                        .font(UI.Fonts.smallButton)
                }
                .foregroundStyle(theme.accent)
                .padding(.vertical, UI.CreateRecipe.addButtonVerticalPadding)
                .frame(maxWidth: .infinity)
                .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: UI.CreateRecipe.addButtonCornerRadius, style: .continuous))
            }
        }
    }

    // MARK: - Step 3: Steps

    private var step3Steps: some View {
        VStack(alignment: .leading, spacing: UI.CreateRecipe.stepsSpacing) {
            Text("COOKING STEPS")
                .sectionLabel()

            VStack(spacing: UI.CreateRecipe.stepsRowSpacing) {
                ForEach(Array(viewModel.stepRows.enumerated()), id: \.element.id) { i, _ in
                    StepInputRow(
                        index: i,
                        text: Binding(
                            get: { viewModel.stepRows[i].text },
                            set: { viewModel.stepRows[i].text = $0 }
                        ),
                        canDelete: viewModel.stepRows.count > 1,
                        onDelete: { viewModel.removeStepRow(at: i) }
                    )
                }
            }

            Button {
                withAnimation(UI.Anim.springQuick) {
                    viewModel.addStepRow()
                }
            } label: {
                HStack(spacing: UI.CreateRecipe.addButtonSpacing) {
                    Image(systemName: "plus.circle.fill")
                        .font(UI.Fonts.iconMedium)
                    Text("Add Step")
                        .font(UI.Fonts.smallButton)
                }
                .foregroundStyle(theme.accent)
                .padding(.vertical, UI.CreateRecipe.addButtonVerticalPadding)
                .frame(maxWidth: .infinity)
                .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: UI.CreateRecipe.addButtonCornerRadius, style: .continuous))
            }
        }
    }

    // MARK: - Step 4: Details

    private var step4Details: some View {
        VStack(alignment: .leading, spacing: UI.CreateRecipe.detailsSpacing) {
            VStack(alignment: .leading, spacing: UI.CreateRecipe.detailItemSpacing) {
                Text("COOK TIME")
                    .sectionLabel()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UI.CreateRecipe.cookTimeChipSpacing) {
                        ForEach([5, 10, 15, 20, 30, 45, 60, 90], id: \.self) { time in
                            CookTimeChip(
                                time: time,
                                isSelected: viewModel.cookTimeMinutes == time,
                                onTap: { viewModel.cookTimeMinutes = time }
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: UI.CreateRecipe.detailItemSpacing) {
                Text("SERVINGS")
                    .sectionLabel()

                HStack(spacing: UI.CreateRecipe.servingsSpacing) {
                    Button {
                        if viewModel.servings > 1 { withAnimation { viewModel.servings -= 1 } }
                    } label: {
                        Image(systemName: "minus")
                            .font(UI.Fonts.buttonIcon)
                            .foregroundStyle(viewModel.servings > 1 ? theme.text1 : theme.text3)
                            .frame(width: UI.CreateRecipe.servingsButtonSize, height: UI.CreateRecipe.servingsButtonSize)
                            .background(theme.surface, in: Circle())
                    }

                    Text("\(viewModel.servings)")
                        .font(UI.Fonts.largeTitle)
                        .foregroundStyle(theme.text1)
                        .frame(width: UI.CreateRecipe.servingsValueWidth)

                    Button {
                        if viewModel.servings < 12 { withAnimation { viewModel.servings += 1 } }
                    } label: {
                        Image(systemName: "plus")
                            .font(UI.Fonts.buttonIcon)
                            .foregroundStyle(viewModel.servings < 12 ? theme.text1 : theme.text3)
                            .frame(width: UI.CreateRecipe.servingsButtonSize, height: UI.CreateRecipe.servingsButtonSize)
                            .background(theme.surface, in: Circle())
                    }
                }
                .padding(UI.CreateRecipe.servingsPadding)
                .frostCard(cornerRadius: UI.Common.cardCornerRadius)
            }

            VStack(alignment: .leading, spacing: UI.CreateRecipe.detailItemSpacing) {
                Text("DIFFICULTY")
                    .sectionLabel()

                HStack(spacing: UI.CreateRecipe.difficultySpacing) {
                    ForEach(Array(zip(CreateRecipeViewModel.difficulties,
                                      [theme.mint, theme.accent, theme.rose])), id: \.0) { diff, color in
                        DifficultyButton(
                            title: diff,
                            color: color,
                            isSelected: viewModel.difficulty == diff,
                            onTap: { viewModel.difficulty = diff }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Step 5: Review

    private var step5Review: some View {
        VStack(spacing: UI.CreateRecipe.reviewSpacing) {
            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [theme.accent.opacity(UI.CreateRecipe.opacityHalf), theme.rose.opacity(UI.CreateRecipe.opacityLight)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Text(viewModel.selectedEmoji)
                        .font(.system(size: UI.CreateRecipe.reviewEmojiSize))
                        .shadow(color: .black.opacity(UI.Components.emojiShadowOpacity), radius: UI.Components.emojiShadowRadius, y: UI.Components.emojiShadowY)
                }
                .frame(maxWidth: .infinity)
                .frame(height: UI.CreateRecipe.reviewImageHeight)
                .clipShape(.rect(topLeadingRadius: UI.V2.FrostCard.defaultCornerRadius, topTrailingRadius: UI.V2.FrostCard.defaultCornerRadius))

                VStack(alignment: .leading, spacing: UI.CreateRecipe.reviewContentSpacing) {
                    Text(viewModel.recipeName.isEmpty ? "Untitled Recipe" : viewModel.recipeName)
                        .font(UI.Fonts.inputField)
                        .foregroundStyle(theme.text1)

                    if !viewModel.tagline.isEmpty {
                        Text(viewModel.tagline)
                            .font(UI.Fonts.smallButton)
                            .foregroundStyle(theme.text2)
                    }

                    HStack(spacing: 0) {
                        StatPill(icon: Icons.Discover.clock, value: "\(viewModel.cookTimeMinutes)m",
                                 label: "Time", color: theme.accent)
                        StatPill(icon: Icons.Discover.person2, value: "\(viewModel.servings)",
                                 label: "Serve", color: theme.mint)
                        StatPill(icon: Icons.Discover.chartBar, value: viewModel.difficulty,
                                 label: "Level", color: theme.lavender)
                    }
                    .padding(UI.RecipeDetails.statsPadding)
                    .frostCard()

                    HStack(spacing: UI.CreateRecipe.reviewStatsSpacing) {
                        Label("\(viewModel.validIngredients.count) ingredients", systemImage: "list.bullet")
                        Label("\(viewModel.validSteps.count) steps", systemImage: "number")
                    }
                    .font(UI.Fonts.captionSemibold)
                    .foregroundStyle(theme.text3)
                }
                .padding(UI.CreateRecipe.reviewContentPadding)
            }
            .frostCard(cornerRadius: UI.V2.FrostCard.defaultCornerRadius)
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [theme.bg, theme.bg.opacity(0)],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: UI.CreateRecipe.bottomGradientHeight)
                .allowsHitTesting(false)

            Button {
                if viewModel.isLastStep {
                    viewModel.saveRecipe()
                } else {
                    withAnimation(UI.Anim.springDefault) { viewModel.goNext() }
                }
            } label: {
                HStack(spacing: UI.CreateRecipe.bottomButtonSpacing) {
                    if viewModel.isLastStep {
                        Image(systemName: Icons.CookMode.checkmark)
                            .font(UI.Fonts.buttonIcon)
                    }
                    Text(viewModel.isLastStep ? Strings.CreateRecipe.saveRecipe : Strings.CreateRecipe.next)
                        .font(UI.Fonts.buttonLabel)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, UI.CreateRecipe.bottomButtonVerticalPadding)
                .background(
                    LinearGradient(colors: [theme.accent, theme.rose],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: UI.CreateRecipe.bottomButtonCornerRadius, style: .continuous)
                )
                .neonGlow(theme.accent, radius: UI.Common.neonRadiusDefault)
            }
            .disabled(!viewModel.isCurrentStepValid)
            .opacity(viewModel.isCurrentStepValid ? 1 : UI.CreateRecipe.disabledOpacity)
            .padding(.horizontal, UI.CreateRecipe.bottomPaddingH)
            .padding(.bottom, UI.CreateRecipe.bottomPaddingV)
        }
        .background(theme.bg)
    }
}
