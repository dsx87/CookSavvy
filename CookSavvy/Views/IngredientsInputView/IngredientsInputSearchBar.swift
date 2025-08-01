//
//  IngredientsInputSearchBar.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputSearchBar: View {
    @Binding var selectedIngredients: Set<Ingredient>
    @Binding var cameraTapped: Bool
    @Binding var text: String
    var body: some View {
        HStack {


            TextField("Type an ingredient",
                      text: $text)
            Button {
                cameraTapped = true
            } label: {
                Image(systemName: "camera")
                    .tint(.black)
            }
            Image(systemName: "magnifyingglass")
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.borderOrange, lineWidth: 3)
        }
        .background {
            Color.white
        }
            
    }
}

#Preview("Search Bar") {
    IngredientsInputSearchBar(selectedIngredients: .constant([]), cameraTapped: .constant(false), text: .constant(""))
}
