//
//  RecipesResultView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

struct RecipesResultView: View {
    let selectedIngredients: Set<Ingredient>
    @Binding var navigationPath: NavigationPath
    
    init(selectedIngredients: Set<Ingredient>, navigationPath: Binding<NavigationPath> = .constant(.init())) {
        self.selectedIngredients = selectedIngredients
        self._navigationPath = navigationPath
    }
    
    var body: some View {
            
        List((0..<10).map ({ _ in Recipe()}), id: \.self) { recipe in
                RecipeResultCellView(recipe: recipe)
                    .onTapGesture {
                        navigationPath.append(recipe)
                    }
            }
            .listRowSpacing(18)
            .navigationTitle("Recipe search result")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(alignment: .leading) {
                        Text("Recipe search result")
                        SearchResultsHeader(count: 2, ingredients: selectedIngredients)
                        
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        navigationPath.removeLast()
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailsView(recipe: recipe)
            }
    }
}

#Preview("RecipesResultView") {
    RecipesResultView(selectedIngredients: ["Pasta, Basta, Something"], navigationPath: .constant(.init()))
}


struct RecipeResultCellView: View {
    let recipe: Recipe
    var body: some View {
        HStack {
            AsyncImageDisk(imageName: recipe.image) {
                DefaultPlaceholder()
            }
            VStack(alignment:.leading) {
                Text(recipe.title)
                RecipeResultCellAdditionalInfoView(info: recipe.additionalInfo)
                RecipeResultCellIngredientsView(ingredients: recipe.ingredients)
            }
        }
        
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
