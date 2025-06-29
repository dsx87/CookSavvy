//
//  FastIngredientSelectorView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//
import SwiftUI

struct FastIngredientSelectorView: View {
    private static let defaultFastIngredients: [String] = [
        ("Chicken", "🍗"),
        ("Rice", "🍚"),
        ("Pasta", "🍝"),
        ("Tomato", "🍅"),
        ("Onion", "🧅"),
        ("Garlic", "🧄"),
        ("Egg", "🥚"),
        ("Milk", "🥛"),
        ("Cheese", "🧀")
    ].map { $0.1 + "\n" + $0.0 }
    
    let fastIngredients: [String]
    let size: Int
    @Binding var selectedIngredients: Set<String>
    
    init(
        fastIngredients: [String] = Self.defaultFastIngredients,
        size: Int = 3,
        selectedIngredients: Binding<Set<String>>
    ) {
        var fastIngredients = fastIngredients
        let ingredientsCount = fastIngredients.count
        let expectedCount = size*size
        if ingredientsCount > expectedCount {
            fastIngredients = Array(fastIngredients.prefix(expectedCount))
        }
        if ingredientsCount < expectedCount {
            let diff = expectedCount - ingredientsCount
            let emptyIngredients = (0..<diff).map { _ in ""}
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
                        FastIngredientCellView(text: fastIngredients[3*row + col]) { str in
                            if selectedIngredients.contains(str) {
                                selectedIngredients.remove(str)
                            } else {
                                selectedIngredients.insert(str)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("FastIngredientSelectorView") {
    FastIngredientSelectorView(selectedIngredients: .constant([]))
}
