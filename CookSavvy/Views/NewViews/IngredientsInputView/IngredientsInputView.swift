//
//  IngredientsInputView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputView: View {
    
    @State var ingredientText: String = ""
    @State var ingredients: [String] = (0..<3).map { "Ingr\($0)" }
    @State var fastIngredients: [FastIngredient] = [
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
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SearchBar(text: $ingredientText)
                SelectedIngredientsView(ingredientsNames: $ingredients)
                FastIngredientSelectorView(ingredients: fastIngredients.map { $0.1 + "\n" + $0.0 })
                Spacer()
                FindRecipesButton {
                    
                }

            }
            .padding()
            .background(content: {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(Color.backOrange2)
            })
            
            .navigationTitle("Ingredients Input")

        }
        
    }
}

#Preview("IngredientsInputView") {
    IngredientsInputView()
}
