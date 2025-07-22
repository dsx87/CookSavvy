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
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(Color.white)
                .shadow(radius: 0.2, x: 0.2, y: 0.2)
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
