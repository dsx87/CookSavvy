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
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: UI.RecipeDetails.cardCornerRadius)
                .foregroundStyle(theme.card)
                .shadow(color: .black.opacity(0.08), radius: UI.RecipeDetails.cardShadowRadius, x: UI.RecipeDetails.cardShadowOffset, y: UI.RecipeDetails.cardShadowOffset)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title)
                    .foregroundStyle(theme.text1)
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.callout)
                        .foregroundStyle(theme.text2)
                }
            }
            .padding()
        }
    }
}

#Preview("RecipeDetailsList") {
    RecipeDetailsList(title: "Title", items: ["First", "Second", "Third"])
}
