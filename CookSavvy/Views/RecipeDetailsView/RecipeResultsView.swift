//
//  RecipeResultsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 24/06/2025.
//

import SwiftUI

struct RecipeDetailMockup: View {
    let recipe: Recipe
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(recipe.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal)
                
                // Ingredients Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredients")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(ingredientsString(recipe))
                        .font(.system(size: 14))
                        .foregroundColor(.sageGreen)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.sageGreen, lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Instructions Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instructions")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { (index, str) in
                        Text("\(index+1). " + str)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.sageGreen, lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Add to Shopping List Button
                Button(action: {}) {
                    Text("Add Missing to Shopping List")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.terracotta)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
        }
        .background(Color.cream)
        .navigationBarTitleDisplayMode(.inline)
    }
    func ingredientsString(_ recipe: Recipe) -> String {
        " • " + recipe.ingredients.joined(separator: "\n • ")
    }
}

//// MARK: - Colors
//extension Color {
//    static let cream = Color(red: 1.0, green: 0.97, blue: 0.94)
//    static let sageGreen = Color(red: 0.66, green: 0.71, blue: 0.64)
//    static let terracotta = Color(red: 0.85, green: 0.47, blue: 0.38)
//}

// MARK: - Preview
#Preview {
    NavigationView {
        RecipeDetailMockup(recipe: Recipe())
    }
}
