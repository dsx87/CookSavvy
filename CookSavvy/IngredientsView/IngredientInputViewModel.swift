//
//  IngredientInputViewModel.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import Combine

class IngredientInputViewModel: ObservableObject {
    @Published var ingredients: String = ""
    @Published var isFindRecipesButtonEnabled: Bool = false
    @Published var navigateToRecipes: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Bind ingredients to button state
        $ingredients
            .map { !$0.isEmpty }
            .assign(to: \.isFindRecipesButtonEnabled, on: self)
            .store(in: &cancellables)
    }
    
    func findRecipesTapped() {
        navigateToRecipes = true
    }
}
