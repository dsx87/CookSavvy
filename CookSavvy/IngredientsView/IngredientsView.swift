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
                TextField("Type ingredients (e.g., chicken, rice)", text: $viewModel.ingredients)
                    .font(.system(size: 18))
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.sageGreen, lineWidth: 1)
                    )
                    .textFieldStyle(PlainTextFieldStyle())
                
                Spacer()
                
                // Find Recipes Button
                NavigationLink(destination: RecipeView(), isActive: $viewModel.navigateToRecipes) {
                    Text("Find Recipes")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.ingredients.isEmpty ? Color.gray : Color.terracotta)
                        .cornerRadius(16)
                }
                .disabled(viewModel.ingredients.isEmpty)
                .opacity(viewModel.ingredients.isEmpty ? 0.5 : 1.0)
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



#Preview {
    IngredientsView(viewModel: IngredientInputViewModel())
}


