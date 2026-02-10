//
//  IngredientsInputAutocompletion.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 01/08/2025.
//

import SwiftUI

struct IngredientsInputAutocompletion: View {
    @Binding var ingredients: [Ingredient]
    @Binding var selectedIngredients: Set<Ingredient>
    
    var body: some View {
        List(ingredients) { ingr in
            HStack {
                Button {
                    if selectedIngredients.contains(ingr) {
                        selectedIngredients.remove(ingr)
                    } else {
                        selectedIngredients.insert(ingr)
                    }
                } label: {
                    Text(ingr.name)
                }
                
                Spacer()
                if selectedIngredients.contains(ingr) {
                    Image(systemName: UI.IngredientsInput.autocompleteSelectedIcon)
                }
            }
        }
    }
}

#Preview("IngredientsInputAutocompletion") {
    IngredientsInputAutocompletion(ingredients: .constant((0..<3).map {  Ingredient(name: "Ingr\($0)" )}), selectedIngredients: .constant([Ingredient(name: "Ingr\(1)")]))
}
