//
//  RecipeDetailsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct RecipeDetailsView: View {
    let recipe: Recipe
    var body: some View {
        
        VStack(alignment: .leading) {
            AsyncImageDisk(imageName: recipe.image) {
                DefaultPlaceholder()
            }
            .frame(maxHeight: 250)
            Group {
                Text(recipe.title)
                    .font(.title)
                RecipeDetailsAdditionalInfo(info: recipe.additionalInfo)
                RecipeDetailsList(
                    title: "🛒 Ingredients",
                    items: recipe.ingredients.map { "• " + $0.emoji + " " + $0.name }
                )
                RecipeDetailsList(
                    title: "🧑‍🍳 Instructions",
                    items: recipe.instructions.map { "• " + $0 }
                )
            }
            .padding(.horizontal)
        }
        
        .background {
            Color.lightGrayBack
                .ignoresSafeArea()
        }
    }
}


#Preview("RecipeDetailsView") {
    RecipeDetailsView(recipe: .init())
}



extension Recipe.AdditionalInfo.InfoType {
    var asTuple:(title: String, value: String) {
        (title:self.asEmoji + " " + self.title, value: stringValue)
    }
    
    var isNotEmpty: Bool {
        self != .empty
    }
}
