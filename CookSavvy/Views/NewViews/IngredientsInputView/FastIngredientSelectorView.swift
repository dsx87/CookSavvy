//
//  FastIngredientSelectorView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//
import SwiftUI

struct FastIngredientSelectorView: View {
    let ingredients: [String]
    var body: some View {
        Grid {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { col in
                        FastIngredientCellView(text: ingredients[3*row + col])
                    }
                }
            }
        }
    }
}

#Preview("FastIngredientSelectorView") {
    FastIngredientSelectorView(ingredients: [])
}
