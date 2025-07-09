//
//  IngredientsInputView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputView: View {
    @State var findRecipesTapped = false
    @State var selectedIngredients: Set<Ingredient> = Set((0..<3).map {  Ingredient(name: "Ingr\($0)", emoji: "🍔" )})
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                IngredientsInputSearchBar(selectedIngredients: $selectedIngredients)
                IngredientsInputSelectedIngredients(ingredientsNames: $selectedIngredients)
                IngredientsInputFastIngredientSelector(selectedIngredients: $selectedIngredients)
                Spacer(minLength: 150)
                IngredientsInputFindRecipesButton(disabled: selectedIngredients.isEmpty) {
                    findRecipesTapped = true
                }
            }
            .padding()
            .background(content: {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(Color.backOrange2)
                    .ignoresSafeArea()
            })
            
            .navigationTitle("Ingredients Input")
            .navigationDestination(isPresented: $findRecipesTapped) {
                RecipesResultView(selectedIngredients: selectedIngredients)
            }
        }
        
    }
}

#Preview("IngredientsInputView") {
    IngredientsInputView()
}
