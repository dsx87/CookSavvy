//
//  RecipesResultView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 03/07/2025.
//

import SwiftUI

struct RecipesResultView: View {
    let selectedIngredients: Set<Ingredient>
    
    var body: some View {
        NavigationStack {
            
            List(0..<10, id: \.self) { recipe in
                RecipeResultCellView(recipe: .init())
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
                        
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

#Preview("RecipesResultView") {
    RecipesResultView(selectedIngredients: ["Pasta, Basta, Something"])
}


struct RecipeResultCellView: View {
    let recipe: Recipe
    var body: some View {
        HStack {
            AsyncImageDisk(imageName: recipe.image) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .foregroundStyle(Color.backOrange)
                        .frame(width: 100, height: 100)
                    ProgressView()
                    
                }
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
            if let time = info.time {
                VStack {
                    Text("⏱️")
                    Text(time)
                }
                
            }
            if let servings = info.servings {
                VStack {
                    Text("👥")
                    Text("\(servings)")
                }
            }
            if let complexity = info.complexity {
                VStack {
                    Text("📊")
                    Text("\(complexity)")
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
                .frame(width: .infinity, height: 20)
            Text(name)
                .font(.caption)
                
        }
    }
}

#Preview("RecipeResultCellIngredientsView") {
    RecipeResultCellIngredientView(name: "Ingredient")
}

struct RecipeResultCellIngredientsView: View {
    let ingredients: [String]
    var body: some View {
        HStack {
            ForEach(0..<(min(ingredients.count, 3)), id: \.self) { i in
                RecipeResultCellIngredientView(name: ingredients[i])
            }
        }
    }
}

#Preview {
    RecipeResultCellIngredientsView(ingredients: ["one", "two", "three"])
}
