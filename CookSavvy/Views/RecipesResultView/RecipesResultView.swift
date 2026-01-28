//
//  RecipesResultView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

struct RecipesResultView: View {
    @StateObject var viewModel: RecipesResultViewModel
    
    var body: some View {
        Group {
            if viewModel.isWaitingForDatabase {
                VStack(spacing: UIConstants.statusStackSpacing) {
                    ProgressView()
                        .scaleEffect(UIConstants.statusProgressScale)
                    Text(UIConstants.recipesPreparingDatabaseText)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.isLoading {
                ProgressView(UIConstants.recipesLoadingText)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: UIConstants.statusStackSpacing) {
                    Image(systemName: UIConstants.errorIconName)
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if viewModel.recipes.isEmpty {
                VStack(spacing: UIConstants.statusStackSpacing) {
                    Image(systemName: UIConstants.recipesNoResultsIconName)
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(UIConstants.recipesNoResultsTitle)
                        .font(.headline)
                    Text(UIConstants.recipesNoResultsSubtitle)
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
                .listRowSpacing(UIConstants.recipeResultListRowSpacing)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .leading) {
                    Text(UIConstants.recipesNavigationTitle)
                    SearchResultsHeader(count: viewModel.recipes.count, ingredients: viewModel.selectedIngredients)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    viewModel.handleBack()
                }) {
                    Image(systemName: UIConstants.backButtonIconName)
                }
            }
        }
        .task {
            await viewModel.loadRecipes()
        }
    }
}

#Preview("RecipesResultView") {
    let dbInterface = DBInterface()
    let ingredientsService = IngredientsService(dbInterface: dbInterface)
    let dataImportService = DataImportService(dbInterface: dbInterface)
    return RecipesResultView(
        viewModel: RecipesResultViewModel(
            selectedIngredients: [Ingredient(name: "Pasta"), Ingredient(name: "Tomato")],
            recipeService: RecipeService(dbInterface: dbInterface),
            imageService: ImageService(),
            databaseInitService: DatabaseInitializationService(
                dbInterface: dbInterface,
                ingredientsService: ingredientsService,
                dataImportService: dataImportService
            ),
            userDataService: UserDataService(dbInterface: dbInterface),
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
        HStack(alignment: .top, spacing: UIConstants.recipeCellHorizontalSpacing) {
            AsyncImageDisk(imageName: recipe.image) {
                DefaultPlaceholder()
                    .frame(width: UIConstants.recipeCellImageSize, height: UIConstants.recipeCellImageSize)
                    .cornerRadius(UIConstants.recipeCellImageCornerRadius)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: UIConstants.recipeCellImageSize, height: UIConstants.recipeCellImageSize)
            .cornerRadius(UIConstants.recipeCellImageCornerRadius)
            .clipped()
            
            VStack(alignment: .leading, spacing: UIConstants.recipeCellContentSpacing) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(UIConstants.recipeTitleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                
                RecipeResultCellIngredientsView(ingredients: recipe.ingredients)
            }
            
            Spacer(minLength: UIConstants.recipeCellSpacerMinLength)
        }
        .padding(.vertical, UIConstants.recipeCellVerticalPadding)
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
    
    var body: some View {
        Text(name)
            .font(.caption)
            .lineLimit(UIConstants.ingredientChipLineLimit)
            .truncationMode(.tail)
            .padding(.horizontal, UIConstants.ingredientChipHorizontalPadding)
            .padding(.vertical, UIConstants.ingredientChipVerticalPadding)
            .background(
                Capsule()
                    .fill(Color.backOrange)
            )
    }
}

#Preview("RecipeResultCellIngredientsView") {
    RecipeResultCellIngredientView(name: "Ingredient")
}

struct RecipeResultCellIngredientsView: View {
    let ingredients: [Ingredient]
    private let maxVisibleIngredients = UIConstants.recipeCellMaxVisibleIngredients
    private let maxChipWidth: CGFloat = UIConstants.recipeCellMaxChipWidth
    
    var body: some View {
        VStack(alignment: .leading, spacing: UIConstants.recipeCellIngredientsSpacing) {
            ForEach(0..<min(ingredients.count, maxVisibleIngredients), id: \.self) { i in
                RecipeResultCellIngredientView(name: ingredients[i].name)
            }
            
            if ingredients.count > maxVisibleIngredients {
                Text("\(UIConstants.recipeCellExtraIngredientsPrefix)\(ingredients.count - maxVisibleIngredients)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RecipeResultCellIngredientsView(ingredients: ["one", "two", "three"])
}
