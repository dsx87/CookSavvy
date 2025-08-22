//
//  IngredientsInputFastIngredientSelector.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//
import SwiftUI

struct IngredientsInputFastIngredientSelector: View {
    private static let defaultFastIngredients: [Ingredient] = [
        ("Chicken", "🍗"),
        ("Rice", "🍚"),
        ("Pasta", "🍝"),
        ("Tomato", "🍅"),
        ("Onion", "🧅"),
        ("Garlic", "🧄"),
        ("Egg", "🥚"),
        ("Milk", "🥛"),
        ("Cheese", "🧀")
    ].map { .init(name: $0.0) }
    
    let fastIngredients: [Ingredient]
    let size: Int
    @Binding var selectedIngredients: Set<Ingredient>
    
    init(
        fastIngredients: [Ingredient] = Self.defaultFastIngredients,
        size: Int = 3,
        selectedIngredients: Binding<Set<Ingredient>>
    ) {
        var fastIngredients = fastIngredients
        let ingredientsCount = fastIngredients.count
        let expectedCount = size*size
        if ingredientsCount > expectedCount {
            fastIngredients = Array(fastIngredients.prefix(expectedCount))
        }
        if ingredientsCount < expectedCount {
            let diff = expectedCount - ingredientsCount
            let emptyIngredients: [Ingredient] = (0..<diff).map { _ in .empty}
            fastIngredients.append(contentsOf: emptyIngredients)
        }
        self.fastIngredients = fastIngredients
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
    IngredientsInputFastIngredientSelector(selectedIngredients: .constant([]))
}
