//
//  IngredientInputViewModel.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import Observation
import Foundation

typealias FastIngredient = (String, String)
@Observable class IngredientInputViewModel {
    
    var ingredientsString: String = ""
    var isFindRecipesButtonEnabled: Bool = false
    var navigateToRecipes: Bool = false
    var fastIngredientsRows: Int { fastIngredients.count / 3 }
    let fastIngredientsCols = 3
    var fastIngredients: [FastIngredient] = [
        ("Chicken", "🍗"),
        ("Rice", "🍚"),
        ("Pasta", "🍝"),
        ("Tomato", "🍅"),
        ("Onion", "🧅"),
        ("Garlic", "🧄"),
        ("Egg", "🥚"),
        ("Milk", "🥛"),
        ("Cheese", "🧀")
    ]
    
    init() {
        
    }
    
    func ingredientTapped(_ ingredient: FastIngredient) {
        ingredientsString += " " + ingredient.0.lowercased()
    }
    
    func findRecipesTapped() {
        navigateToRecipes = true
    }
}
