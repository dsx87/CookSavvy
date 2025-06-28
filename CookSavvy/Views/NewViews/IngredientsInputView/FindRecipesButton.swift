//
//  FindRecipesButton.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct FindRecipesButton: View {
    let action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .foregroundStyle(.orange)
                    .frame(width: .infinity, height: 40)
                Text("Find Recipes (2 ingredients)")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

#Preview {
    FindRecipesButton(action: {})
}
