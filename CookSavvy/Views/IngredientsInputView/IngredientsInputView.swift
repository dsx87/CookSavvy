//
//  IngredientsInputView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputView: View {
    let ingredients: [Ingredient] = (0..<3).map {  Ingredient(name: "Ingr\($0)", emoji: "🍔" )}
    @State var selectedIngredients: Set<Ingredient> = Set((0..<3).map {  Ingredient(name: "Ingr\($0)", emoji: "🍔" )})
    @State var searchText: String = ""
    @State var cameraTapped: Bool = false
    @State var navigationPath = NavigationPath()
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 16) {
                IngredientsInputSearchBar(selectedIngredients: $selectedIngredients, cameraTapped: $cameraTapped, text: $searchText)
                    .popover(isPresented: Binding<Bool>(
                        get: { !searchText.isEmpty },
                        set: {_ in } )
                    ) {
                        IngredientsInputAutocompletion(ingredients: ingredients,  selectedIngredients: $selectedIngredients)
                            .frame(width: 400, height: 300)
                            .padding()
                            .presentationCompactAdaptation(.popover)
                    }
                IngredientsInputSelectedIngredients(ingredientsNames: $selectedIngredients)
                IngredientsInputFastIngredientSelector(selectedIngredients: $selectedIngredients)
                Spacer(minLength: 150)
                IngredientsInputFindRecipesButton(disabled: selectedIngredients.isEmpty) {
                    navigationPath.append("RecipesResultView")
                }
            }
            .padding()
            .background(content: {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundStyle(Color.backOrange2)
                    .ignoresSafeArea()
            })
            
            .navigationTitle("Ingredients Input")
            .navigationDestination(for: String.self) { _ in
                RecipesResultView(
                    selectedIngredients: selectedIngredients,
                    navigationPath: $navigationPath
                )
            }
            .popover(isPresented: $cameraTapped, content: {
                    Text("not implmemented yet, close")
                        .presentationCompactAdaptation(.fullScreenCover)
                        .onTapGesture {
                            cameraTapped = false
                        }
            })
        }
        
    }
}

#Preview("IngredientsInputView") {
    IngredientsInputView()
}
