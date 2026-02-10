//
//  RecipeDetailsList.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 23/07/2025.
//

import SwiftUI

struct RecipeDetailsList: View {
    let title: String
    let items: [String]
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: UIConstants.recipeDetailsCardCornerRadius)
                .foregroundStyle(Color.white)
                .shadow(radius: UIConstants.recipeDetailsCardShadowRadius, x: UIConstants.recipeDetailsCardShadowOffset, y: UIConstants.recipeDetailsCardShadowOffset)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title)
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.callout)
                }
            }
            .padding()
        }
    }
}

#Preview("RecipeDetailsList") {
    RecipeDetailsList(title: "Title", items: ["First", "Second", "Third"])
}
