//
//  IngredientInputViewModel.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import Observation
import Foundation

@Observable class IngredientInputViewModel {
    var ingredients: String = ""
    var isFindRecipesButtonEnabled: Bool = false
    var navigateToRecipes: Bool = false
    
    
    init() {
    }
    
    func findRecipesTapped() {
        navigateToRecipes = true
    }
}
