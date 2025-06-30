//
//  SearchBar.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct SearchBar: View {
    @Binding var selectedIngredients: Set<Ingredient>
    
    @State private var text: String = ""
    var body: some View {
        HStack {
            TextField("Type an ingredient",
                      text: $text)
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
    SearchBar(selectedIngredients: .constant([]))
}
