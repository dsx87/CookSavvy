//
//  RecipeListViewModel.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 10/05/2025.
//

import SwiftUI
import Observation


// MARK: - ViewModel
@Observable
class RecipeListViewModel  {
    var recipes: [Recipe] = []
    var areRecipesLoading = false
    var navigateToDetail: Bool = false
    
    private let ingredients: String
    
    init(ingredients: String) {
        self.ingredients = ingredients
        loadRecipes()
    }
    
    private func loadRecipes() {
        Task {
            areRecipesLoading = true
            let csvConv = CSVToJSONReader()
            let zip = Bundle.main.url(forResource: "food-ingredients-and-recipe-dataset-with-images", withExtension: "zip")!
            await Task.yield()
            let parsedRecipes:[Recipe] = try! csvConv.parseCSVFromZip(withURL: zip,
                                                                      usingFilename: "Food Ingredients and Recipe Dataset with Image Name Mapping.csv")
            let userIngredients = ingredients.lowercased().split(separator: " ").map(String.init)
            
            guard !userIngredients.isEmpty else {
                recipes = parsedRecipes
                return
            }
            
            let res = parsedRecipes.filter ( { parsedRecipe in
                let parsedRecipeIngredients = parsedRecipe.cleanedIngredients.map { $0.lowercased() }
                
                for userIngredient in userIngredients {
                    if !parsedRecipeIngredients.contains(where: { $0.contains(userIngredient) }) {
                        return false
                    }
                }
                return true
            })
            recipes = res
            areRecipesLoading = false
            
        }
    }
    func ingredientsString(from recipe: Recipe) -> String {
        " • " + recipe.ingredients.prefix(4).joined(separator: "\n • ") + "\n..."
    }
    
    func viewRecipeTapped() {
        navigateToDetail = true
    }
}

