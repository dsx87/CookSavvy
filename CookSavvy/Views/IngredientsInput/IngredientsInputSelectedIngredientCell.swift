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
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: UI.SelectedIngredient.cellSpacing) {
            Text(ingredient.name)
                .font(.caption2)
            Button {
                action()
            } label: {
                Image(systemName: Icons.SelectedIngredient.remove)
                    .scaleEffect(UI.SelectedIngredient.removeIconScale)
                    .tint(.black)
            }
        }
        .padding(UI.SelectedIngredient.cellPadding)
        .background {
            RoundedRectangle(cornerRadius: .infinity)
                .foregroundStyle(theme.backgroundPrimary)
        }
        
    }
}

#Preview("IngredientsInputSelectedIngredientCell") {
    IngredientsInputSelectedIngredientCell(ingredient: "Ingredient") {
        print("close tapped")
    }
}
