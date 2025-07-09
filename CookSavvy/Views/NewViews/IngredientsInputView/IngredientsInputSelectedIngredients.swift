//
//  IngredientsInputSelectedIngredients.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputSelectedIngredients: View {
    @Binding var ingredientsNames: Set<Ingredient>
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(Array(ingredientsNames), id: \.self) { ingredient in
                    IngredientsInputSelectedIngredientCell(ingredient: ingredient) {
                        ingredientsNames.remove(ingredient)
                    }
                }
            }
        }
    }
}

#Preview("SelectedIngredientsView") {
    IngredientsInputSelectedIngredients(ingredientsNames: .constant(Set((0..<10).map { .init(name: "Ingredient \($0)", emoji: "🍓")  })))
}
