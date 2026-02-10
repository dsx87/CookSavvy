//
//  IngredientsInputFindRecipesButton.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputFindRecipesButton: View {
    var ingredientsNumber: Int
    
    private var disabled: Bool { ingredientsNumber == 0 }
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: UIConstants.findRecipesButtonCornerRadius)
                    .foregroundStyle(disabled ? .gray : .buttonOrange)
                    .frame(maxWidth: .infinity, maxHeight: UIConstants.findRecipesButtonHeight)
                Text(UIConstants.findRecipesButtonTitle)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
        .disabled(disabled)
    }
}

#Preview {
    IngredientsInputFindRecipesButton(ingredientsNumber: 0, action: {})
}
