//
//  IngredientsInputFastIngredientSelector.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//
import SwiftUI

struct IngredientsInputFastIngredientSelector: View {
    
    let fastIngredients: [Ingredient]
    let size: Int
    @Binding var selectedIngredients: Set<Ingredient>
    
    init(
        fastIngredients: [Ingredient],
        size: Int = 3,
        selectedIngredients: Binding<Set<Ingredient>>,
    ) {
        // Use recent ingredients if available, otherwise fall back to defaults
        var ingredientsToUse = fastIngredients
        let ingredientsCount = ingredientsToUse.count
        let expectedCount = size*size
        if ingredientsCount > expectedCount {
            ingredientsToUse = Array(ingredientsToUse.prefix(expectedCount))
        }
        if ingredientsCount < expectedCount {
            let diff = expectedCount - ingredientsCount
            let emptyIngredients: [Ingredient] = (0..<diff).map { _ in .empty}
            ingredientsToUse.append(contentsOf: emptyIngredients)
        }
        self.fastIngredients = ingredientsToUse
        self.size = size
        self._selectedIngredients = Binding(projectedValue: selectedIngredients)
    }
    
    var body: some View {
        Grid {
            ForEach(0..<size, id: \.self) { row in
                GridRow {
                    ForEach(0..<size, id: \.self) { col in
                        IngredientsInputFastIngredientCell(ingredient: fastIngredients[3*row + col]) { ingredient in
                            if selectedIngredients.contains(ingredient) {
                                selectedIngredients.remove(ingredient)
                            } else {
                                selectedIngredients.insert(ingredient)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("FastIngredientSelectorView") {
    IngredientsInputFastIngredientSelector(fastIngredients: [], selectedIngredients: .constant([]))
}
