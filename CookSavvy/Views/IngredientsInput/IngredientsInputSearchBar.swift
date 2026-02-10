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
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {


            TextField(Strings.SearchBar.placeholder,
                      text: $text)
            Button {
                onCameraTapped()
            } label: {
                Image(systemName: Icons.SearchBar.camera)
                    .tint(.black)
            }
            Image(systemName: Icons.SearchBar.magnifying)
        }
        .padding(.horizontal)
        .padding(.vertical, UI.SearchBar.verticalPadding)
        .overlay {
            RoundedRectangle(cornerRadius: UI.SearchBar.cornerRadius)
                .stroke(theme.borderAccent, lineWidth: UI.SearchBar.borderWidth)
        }
        .background {
            Color.white
        }
            
    }
}

#Preview("Search Bar") {
    IngredientsInputSearchBar(selectedIngredients: .constant([]), onCameraTapped: {}, text: .constant(""))
}
