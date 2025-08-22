//
//  IngredientsInputView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

final class IngredientsProvider {
    private let db = DBInterface()
    
    func getIngredientsByString(_ string: String) -> [Ingredient] {
        db.getIngredients(byName: string)
    }
}


final class IngredientsInputViewModel: ObservableObject {
    @Published var ingredients: [Ingredient] = []

    @Published var searchText: String = "" {
        didSet {
            getIngredientsByString(searchText)
        }
    }
    @Published var selectedIngredients: Set<Ingredient> = []
    @Published var cameraViewPresented: Bool = false
    @Published var navigationPath: NavigationPath = NavigationPath()
    
    let navigationTitle = "Ingredients Input"
    
    let ingredientsProvider: IngredientsProvider = .init()
    
    private func getIngredientsByString(_ string: String) {
        guard !string.isEmpty else {
            self.ingredients = []
            return
        }
        self.ingredients = ingredientsProvider.getIngredientsByString(string)
    }
    
    private func clearText() {
        searchText = ""
    }
    
    func autocompletionDidHide() {
        clearText()
    }
    
    init() {
        
    }
    
}

struct IngredientsInputView: View {
    @StateObject var viewModel: IngredientsInputViewModel// = IngredientsInputViewModel()
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            VStack(spacing: 16) {
                IngredientsInputSearchBar(
                    selectedIngredients: $viewModel.selectedIngredients,
                    cameraTapped: $viewModel.cameraViewPresented,
                    text: $viewModel.searchText
                )
                    .popover(isPresented: Binding<Bool>(
                        get: { !viewModel.searchText.isEmpty },
                        set: { isPresented in
                            if !isPresented {
                                viewModel.autocompletionDidHide()
                            }
                        } )
                    ) {
                        IngredientsInputAutocompletion(
                            ingredients: $viewModel.ingredients,
                            selectedIngredients: $viewModel.selectedIngredients
                        )
                            .frame(width: 400, height: 300)
                            .padding()
                            .presentationCompactAdaptation(.popover)
                    }
                IngredientsInputSelectedIngredients(ingredientsNames: $viewModel.selectedIngredients)
                IngredientsInputFastIngredientSelector(selectedIngredients: $viewModel.selectedIngredients)
                Spacer(minLength: 150)
                IngredientsInputFindRecipesButton(disabled: viewModel.selectedIngredients.isEmpty) {
                    viewModel.navigationPath.append("RecipesResultView")
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
                    selectedIngredients: viewModel.selectedIngredients,
                    navigationPath: $viewModel.navigationPath
                )
            }
            .popover(isPresented: $viewModel.cameraViewPresented, content: {
                    Text("not implmemented yet, close")
                        .presentationCompactAdaptation(.fullScreenCover)
                        .onTapGesture {
                            viewModel.cameraViewPresented = false
                        }
            })
        }
        .onAppear {
            let db = DBInterface()
            let rec = db.getIngredients(byName: "chicken")
            print("hello")
        }
        
    }
}

#Preview("IngredientsInputView") {
    IngredientsInputView(viewModel: .init())
}
