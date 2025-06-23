//
//  RecipeListView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 10/05/2025.
//


import SwiftUI
import Observation

// MARK: - View
struct RecipeListView: View {
    @Bindable var viewModel: RecipeListViewModel
    
    var body: some View {
        NavigationStack {
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
                            NavigationLink(destination: RecipeDetailMockup(recipe: recipe),
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
}

// MARK: - Preview
#Preview {
    NavigationView {
        RecipeListView(viewModel: .init(ingredients: "chicken, rice, tomato"))//(ingredients: "chicken, rice, tomato")
    }
}
