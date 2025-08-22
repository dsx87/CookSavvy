//
//  IngredientsInputFastIngredientCell.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputFastIngredientCell: View {
    let ingredient: Ingredient
    let onFastIngredintTap: (Ingredient) -> Void
    var body: some View {
        Button {
            onFastIngredintTap(ingredient)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundStyle(.white)
                VStack {
//                    Text(ingredient.emoji)
//                        .foregroundStyle(.black)
//                        .font(.footnote)
                    Text(ingredient.name)
                        .foregroundStyle(.black)
                        .font(.footnote)
                }
            }
        }
    }
}

#Preview("FastIngredientCellView") {
    IngredientsInputFastIngredientCell(ingredient: "🍎Ingredient Name", onFastIngredintTap: {_ in})
}
