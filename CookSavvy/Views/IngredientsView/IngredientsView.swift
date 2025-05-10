//
//  IngredientsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import SwiftUI

struct IngredientsView: View {
    @Bindable var viewModel: IngredientInputViewModel
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // Title
                Text("What’s in Your Kitchen?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                // Text Field
                TextField("Type ingredients (e.g., chicken, rice)", text: $viewModel.ingredientsString)
                    .font(.system(size: 18))
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.sageGreen, lineWidth: 1)
                    )
                    .textFieldStyle(PlainTextFieldStyle())
                
                FastIngredientsGrid(viewModel: viewModel)
                
                Spacer()
                
                // Find Recipes Button
                NavigationLink(destination: RecipeResultsView(ingredients: viewModel.ingredientsString), isActive: $viewModel.navigateToRecipes) {
                    Text("Find Recipes")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.ingredientsString.isEmpty ? Color.gray : Color.terracotta)
                        .cornerRadius(16)
                }
                .disabled(viewModel.ingredientsString.isEmpty)
                .opacity(viewModel.ingredientsString.isEmpty ? 0.5 : 1.0)
            }
            .padding()
            .background(Color.cream)
            .navigationBarItems(trailing: Button(action: {
                // Settings action (placeholder)
            }) {
                Image(systemName: "gear")
                    .foregroundColor(.sageGreen)
                    .frame(width: 30, height: 30)
            })
        }
    }
}


struct FastIngredientsGrid: View {
    @Bindable var viewModel: IngredientInputViewModel
    
    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(0..<viewModel.fastIngredientsRows, id: \.self) { row in
                GridRow {
                    ForEach(0..<viewModel.fastIngredientsCols, id: \.self) { col in
                        let index = row * 3 + col
                        let ingredient = viewModel.fastIngredients[index]
                        Button(action: {
                            viewModel.ingredientTapped(ingredient)
                        }) {
                            HStack {
                                Text(ingredient.1) // Emoji
                                Text(ingredient.0) // Name
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(
                                viewModel.ingredientsString.contains(ingredient.0.lowercased())
                                    ? Color.terracotta
                                    : Color.white
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.sageGreen, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    FastIngredientsGrid(viewModel: IngredientInputViewModel())
}


#Preview {
    IngredientsView(viewModel: IngredientInputViewModel())
}


