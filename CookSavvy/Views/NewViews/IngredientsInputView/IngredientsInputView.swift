//
//  IngredientsInputView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputView: View {
    
    @State var selectedIngredients: Set<String> = Set((0..<3).map { "Ingr\($0)" })
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SearchBar(selectedIngredients: $selectedIngredients)
                SelectedIngredientsView(ingredientsNames: $selectedIngredients)
                FastIngredientSelectorView(selectedIngredients: $selectedIngredients)
                Spacer(minLength: 150)
                FindRecipesButton(disabled: selectedIngredients.isEmpty) {
                    
                }
            }
            .padding()
            .background(content: {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(Color.backOrange2)
                    .ignoresSafeArea()
            })
            
            .navigationTitle("Ingredients Input")

        }
        
    }
}

#Preview("IngredientsInputView") {
    IngredientsInputView()
}
