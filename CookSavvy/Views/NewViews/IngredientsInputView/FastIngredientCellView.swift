//
//  FastIngredientCellView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct FastIngredientCellView: View {
    let text: String
    let onFastIngredintTap: (String) -> Void
    var body: some View {
        Button {
            onFastIngredintTap(text)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundStyle(.white)
                Text(text)
                    .foregroundStyle(.black)
                    .font(.footnote)
            }
        }
    }
}

#Preview("FastIngredientCellView") {
    FastIngredientCellView(text: "Ingredient Name", onFastIngredintTap: {_ in})
}
