//
//  SelectedIngredientsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct SelectedIngredientsView: View {
    @Binding var ingredientsNames: [String]
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(ingredientsNames, id: \.self) { ingredient in
                    SelectedIngredientCell(name: ingredient) {
                        print(ingredient)
                    }
                }
            }
        }
    }
}

#Preview("SelectedIngredientsView") {
    SelectedIngredientsView(ingredientsNames: .constant((0..<10).map { "Ingredient \($0)" }))
}
