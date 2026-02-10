//
//  SearchResultsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

struct SearchResultsView: View {
    @StateObject var viewModel: SearchResultsViewModel
    
    var body: some View {
        Group {
            if viewModel.isWaitingForDatabase {
                VStack(spacing: UI.Common.stackSpacing) {
                    ProgressView()
                        .scaleEffect(UI.Common.progressScale)
                    Text(UI.SearchResults.preparingDatabaseText)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.isLoading {
                ProgressView(UI.SearchResults.loadingText)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: UI.Common.stackSpacing) {
                    Image(systemName: UI.Common.errorIcon)
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if viewModel.recipes.isEmpty {
                VStack(spacing: UI.Common.stackSpacing) {
                    Image(systemName: UI.SearchResults.noResultsIcon)
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(UI.SearchResults.noResultsTitle)
                        .font(.headline)
                    Text(UI.SearchResults.noResultsSubtitle)
                        .foregroundColor(.secondary)
                }
            } else {
                List(viewModel.recipes, id: \.id) { recipe in
                    RecipeResultCellView(
                        recipe: recipe
                    )
                    .onTapGesture {
                        viewModel.handleRecipeSelection(recipe)
                    }
                }
                .listRowSpacing(UI.RecipeCell.listRowSpacing)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .leading) {
                    Text(UI.SearchResults.navigationTitle)
                    SearchResultsHeader(count: viewModel.recipes.count, ingredients: viewModel.selectedIngredients)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    viewModel.handleBack()
                }) {
                    Image(systemName: UI.Common.backButtonIcon)
                }
            }
        }
        .task {
            await viewModel.loadRecipes()
        }
    }
}

#Preview("SearchResultsView") {
    let dbInterface = DBInterface()
    let ingredientsService = IngredientsService(dbInterface: dbInterface)
    let dataImportService = DataImportService(dbInterface: dbInterface)
    SearchResultsView(
        viewModel: SearchResultsViewModel(
            selectedIngredients: [Ingredient(name: "Pasta"), Ingredient(name: "Tomato")],
            recipeService: RecipeService(dbInterface: dbInterface),
            imageService: ImageService(),
            databaseInitService: DatabaseInitializationService(
                dbInterface: dbInterface,
                ingredientsService: ingredientsService,
                dataImportService: dataImportService
            ),
            userDataService: UserDataService(dbInterface: dbInterface),
            subscriptionService: MockSubscriptionService(),
            coordinator: nil
        )
    )
}


struct RecipeResultCellView: View {
    let recipe: Recipe
    
    init(recipe: Recipe) {
        self.recipe = recipe
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: UI.RecipeCell.horizontalSpacing) {
            AsyncImageDisk(imageName: recipe.image) {
                DefaultPlaceholder()
                    .frame(width: UI.RecipeCell.imageSize, height: UI.RecipeCell.imageSize)
                    .cornerRadius(UI.RecipeCell.imageCornerRadius)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: UI.RecipeCell.imageSize, height: UI.RecipeCell.imageSize)
            .cornerRadius(UI.RecipeCell.imageCornerRadius)
            .clipped()
            
            VStack(alignment: .leading, spacing: UI.RecipeCell.contentSpacing) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(UI.RecipeCell.titleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                
                RecipeResultCellIngredientsView(ingredients: recipe.ingredients)
            }
            
            Spacer(minLength: UI.RecipeCell.spacerMinLength)
        }
        .padding(.vertical, UI.RecipeCell.verticalPadding)
    }
}

#Preview("RecipeResultCellView") {
    RecipeResultCellView(recipe: .init())
}


struct RecipeResultCellAdditionalInfoView: View {
    let info: Recipe.AdditionalInfo
    var body: some View {
        HStack {
            ForEach(info.infos, id: \.self) { info in
                VStack {
                    Text(info.asEmoji)
                    Text(info.stringValue)
                }
            }
        }
    }
}

#Preview("RecipeResultCellAdditionalInfoView") {
    RecipeResultCellAdditionalInfoView(info: .empty)
}


struct RecipeResultCellIngredientView: View {
    let name: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(name)
            .font(.caption)
            .lineLimit(UI.IngredientChip.lineLimit)
            .truncationMode(.tail)
            .padding(.horizontal, UI.IngredientChip.horizontalPadding)
            .padding(.vertical, UI.IngredientChip.verticalPadding)
            .background(
                Capsule()
                    .fill(theme.backgroundPrimary)
            )
    }
}

#Preview("RecipeResultCellIngredientsView") {
    RecipeResultCellIngredientView(name: "Ingredient")
}

struct RecipeResultCellIngredientsView: View {
    let ingredients: [Ingredient]
    private let maxVisibleIngredients = UI.RecipeCell.maxVisibleIngredients
    private let maxChipWidth: CGFloat = UI.RecipeCell.maxChipWidth
    
    var body: some View {
        VStack(alignment: .leading, spacing: UI.RecipeCell.ingredientsSpacing) {
            ForEach(0..<min(ingredients.count, maxVisibleIngredients), id: \.self) { i in
                RecipeResultCellIngredientView(name: ingredients[i].name)
            }
            
            if ingredients.count > maxVisibleIngredients {
                Text("\(UI.RecipeCell.extraIngredientsPrefix)\(ingredients.count - maxVisibleIngredients)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RecipeResultCellIngredientsView(ingredients: ["one", "two", "three"])
}
