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
                        recipe: recipe
//                        image: viewModel.getImage(for: recipe)
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
    
    init(recipe: Recipe) {
        self.recipe = recipe
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImageDisk(imageName: recipe.image) {
                DefaultPlaceholder()
                    .frame(width: 70, height: 70)
                    .cornerRadius(10)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 70, height: 70)
            .cornerRadius(10)
            .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                RecipeResultCellIngredientsView(ingredients: recipe.ingredients)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
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
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
    private let maxVisibleIngredients = 3
    private let maxChipWidth: CGFloat = 100
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<min(ingredients.count, maxVisibleIngredients), id: \.self) { i in
                RecipeResultCellIngredientView(name: ingredients[i].name)
            }
            
            if ingredients.count > maxVisibleIngredients {
                Text("+\(ingredients.count - maxVisibleIngredients)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RecipeResultCellIngredientsView(ingredients: ["one", "two", "three"])
}
