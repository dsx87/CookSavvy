//
//  IngridientsView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import SwiftUI

struct IngridientsView: View {
    @State private var ingredients: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // Title
                Text("What’s in Your Kitchen?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                // Text Field
                TextField("Type ingredients (e.g., chicken, rice)", text: $ingredients)
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
                NavigationLink(destination: RecipeView()) {
                    Text("Find Recipes")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ingredients.isEmpty ? Color.gray : Color.terracotta)
                        .cornerRadius(16)
                }
                .disabled(ingredients.isEmpty)
                .opacity(ingredients.isEmpty ? 0.5 : 1.0)
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
    IngridientsView()
}


