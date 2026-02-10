//
//  IngredientsInputSelectedIngredientCell.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputSelectedIngredientCell: View {
    let ingredient: Ingredient
    let action: () -> Void
    var body: some View {
        HStack(spacing: UIConstants.selectedIngredientCellSpacing) {
            Text(ingredient.name)
                .font(.caption2)
            Button {
                action()
            } label: {
                Image(systemName: UIConstants.selectedIngredientRemoveIconName)
                    .scaleEffect(UIConstants.selectedIngredientRemoveIconScale)
                    .tint(.black)
            }
        }
        .padding(UIConstants.selectedIngredientCellPadding)
        .background {
            RoundedRectangle(cornerRadius: .infinity)
                .foregroundStyle(Color.backOrange)
        }
        
    }
}

#Preview("IngredientsInputSelectedIngredientCell") {
    IngredientsInputSelectedIngredientCell(ingredient: "Ingredient") {
        print("close tapped")
    }
}
