//
//  Recipe.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 10/05/2025.
//


import SwiftUI
import Observation

// MARK: - Model
//struct RecipeViewRecipe: Identifiable {
//    let id = UUID()
//    let title: String
//    let match: String
//    let missing: String
//}

// MARK: - View
struct RecipeResultsView: View {
    @Bindable var viewModel: RecipeResultsViewModel
    
//    init(ingredients: String) {
//        _viewModel = Binding(wrappedValue: RecipeResultsViewModel(ingredients: ingredients))
//    }
    
    var body: some View {
        VStack {
            // Title
            Text("Recipe Results")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 20)
            if viewModel.areRecipesLoading {
                
            } else {
                // Recipe List
                List(viewModel.recipes) { recipe in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recipe.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                        
                        Text(viewModel.ingredientsString(from: recipe))
                            .font(.system(size: 14))
                            .foregroundColor(.sageGreen)
                        
                        // View Recipe Button
                        NavigationLink(
                            destination: Text("Recipe Detail Placeholder"),
                            isActive: $viewModel.navigateToDetail
                        ) {
                            Button(action: {
                                viewModel.viewRecipeTapped()
                            }) {
                                Text("View Recipe")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.terracotta)
                                    .cornerRadius(10)
                            }
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
                }
                .listStyle(.plain)
                
                Spacer()
            }

        }
        .background(Color.cream)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        RecipeResultsView(viewModel: .init(ingredients: "chicken, rice, tomato"))//(ingredients: "chicken, rice, tomato")
    }
}
