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
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: UI.FindButton.cornerRadius)
                    .foregroundStyle(disabled ? .gray : theme.buttonPrimary)
                    .frame(maxWidth: .infinity, maxHeight: UI.FindButton.height)
                Text(Strings.FindButton.title)
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
