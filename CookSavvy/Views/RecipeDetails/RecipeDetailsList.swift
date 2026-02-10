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
            RoundedRectangle(cornerRadius: UI.RecipeDetails.cardCornerRadius)
                .foregroundStyle(Color.white)
                .shadow(radius: UI.RecipeDetails.cardShadowRadius, x: UI.RecipeDetails.cardShadowOffset, y: UI.RecipeDetails.cardShadowOffset)
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
