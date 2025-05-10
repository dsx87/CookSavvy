//
//  RecipeResultsViewModel.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 10/05/2025.
//

import SwiftUI
import Observation


// MARK: - ViewModel
@Observable
class RecipeResultsViewModel  {
    var recipes: [RecipeViewRecipe] = []
    var navigateToDetail: Bool = false
    
    private let ingredients: String
    
    init(ingredients: String) {
        self.ingredients = ingredients
        loadRecipes()
    }
    
    private func loadRecipes() {
        // Mock recipe data based on ingredients (replace with real matching logic later)
        let ingredientList = ingredients.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        recipes = [
            RecipeViewRecipe(title: "Chicken Stir-Fry", match: ingredientList.contains("chicken") ? "Chicken, Rice" : "Rice", missing: "Soy Sauce, Bell Peppers"),
            RecipeViewRecipe(title: "Pasta Primavera", match: ingredientList.contains("pasta") ? "Pasta, Cheese" : "Cheese", missing: "Broccoli, Cream"),
            RecipeViewRecipe(title: "Tomato Soup", match: ingredientList.contains("tomato") ? "Tomato, Onion" : "Onion", missing: "Basil, Cream")
        ]
    }
    
    func viewRecipeTapped() {
        navigateToDetail = true
    }
}