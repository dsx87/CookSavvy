//
//  RecipesResultView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

struct RecipesResultView: View {
    @ObservedObject var viewModel: RecipesResultViewModel
    
    var body: some View {
        Group {
            if viewModel.isWaitingForDatabase {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Preparing recipes database...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.isLoading {
                ProgressView("Loading recipes...")
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if viewModel.recipes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recipes found")
                        .font(.headline)
                    Text("Try different ingredients")
                        .foregroundColor(.secondary)
                }
            } else {
                List(viewModel.recipes, id: \.id) { recipe in
                    RecipeResultCellView(
                        recipe: recipe,
                        image: viewModel.getImage(for: recipe)
                    )
                    .onTapGesture {
                        viewModel.handleRecipeSelection(recipe)
                    }
                }
                .listRowSpacing(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .leading) {
                    Text("Recipe search result")
                    SearchResultsHeader(count: viewModel.recipes.count, ingredients: viewModel.selectedIngredients)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    viewModel.handleBack()
                }) {
                    Image(systemName: "chevron.left")
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
    let image: UIImage?
    
    var body: some View {
        HStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
            } else {
                DefaultPlaceholder()
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading) {
                Text(recipe.title)
                RecipeResultCellAdditionalInfoView(info: recipe.additionalInfo)
                RecipeResultCellIngredientsView(ingredients: recipe.ingredients)
            }
        }
    }
}

#Preview("RecipeResultCellView") {
    RecipeResultCellView(recipe: .init(), image: nil)
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
        ZStack {
            RoundedRectangle(cornerRadius: .infinity)
                .foregroundStyle(Color.backOrange)
                .frame(maxWidth: .infinity, maxHeight: 20)
            Text(name)
                .font(.caption)
                
        }
    }
}

#Preview("RecipeResultCellIngredientsView") {
    RecipeResultCellIngredientView(name: "Ingredient")
}

struct RecipeResultCellIngredientsView: View {
    let ingredients: [Ingredient]
    var body: some View {
        HStack {
            ForEach(0..<(min(ingredients.count, 3)), id: \.self) { i in
                RecipeResultCellIngredientView(name: ingredients[i].name)
            }
        }
    }
}

#Preview {
    RecipeResultCellIngredientsView(ingredients: ["one", "two", "three"])
}
