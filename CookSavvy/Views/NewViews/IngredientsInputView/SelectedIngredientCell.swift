//
//  SelectedIngredientCell.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct SelectedIngredientCell: View {
    let ingredient: Ingredient
    let action: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            Text(ingredient.name)
                .font(.caption2)
            Button {
                action()
            } label: {
                Image(systemName: "xmark")
                    .scaleEffect(0.5)
                    .tint(.black)
            }
        }
        .padding(7)
        .background {
            RoundedRectangle(cornerRadius: .infinity)
                .foregroundStyle(Color.backOrange)
        }
        
    }
}

#Preview("SelectedIngredientCell") {
    SelectedIngredientCell(ingredient: "Ingredient") {
        print("close tapped")
    }
}
