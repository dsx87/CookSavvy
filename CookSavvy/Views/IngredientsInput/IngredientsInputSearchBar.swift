//
//  IngredientsInputSearchBar.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputSearchBar: View {
    @Binding var selectedIngredients: Set<Ingredient>
    let onCameraTapped: () -> Void
    @Binding var text: String
    var body: some View {
        HStack {


            TextField(UIConstants.ingredientsSearchPlaceholderText,
                      text: $text)
            Button {
                onCameraTapped()
            } label: {
                Image(systemName: UIConstants.ingredientsSearchCameraIconName)
                    .tint(.black)
            }
            Image(systemName: UIConstants.ingredientsSearchMagnifyingIconName)
        }
        .padding(.horizontal)
        .padding(.vertical, UIConstants.searchBarVerticalPadding)
        .overlay {
            RoundedRectangle(cornerRadius: UIConstants.searchBarCornerRadius)
                .stroke(Color.borderOrange, lineWidth: UIConstants.searchBarBorderWidth)
        }
        .background {
            Color.white
        }
            
    }
}

#Preview("Search Bar") {
    IngredientsInputSearchBar(selectedIngredients: .constant([]), onCameraTapped: {}, text: .constant(""))
}
