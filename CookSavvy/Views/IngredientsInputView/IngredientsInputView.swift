//
//  IngredientsInputView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

final class IngredientsProvider {
//    private let db = DBInterface()
//    
//    func getIngredientsByString(_ string: String) -> [Ingredient] {
//        db.getIngredients(byName: string)
//    }
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
        self.ingredients = [] //ingredientsProvider.getIngredientsByString(string)
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
            let ingrURL = Bundle.main.url(forResource: "Food", withExtension: "json")!
            let data = try! Data(contentsOf: ingrURL)
            let ingr = try! JSONDecoder().decode([Ingredient].self, from: data)
            try! db.insertIngredients(ingr)
            let csvConv = CSVToJSONReader()
            let zip = Bundle.main.url(forResource: "food-ingredients-and-recipe-dataset-with-images", withExtension: "zip")!
            let res:[Recipe] = try! csvConv.parseCSVFromZip(zipURL: zip, csvFilename: "Food Ingredients and Recipe Dataset with Image Name Mapping.csv", useCache: false)
            try! db.insertRecipes(res)
            
            
            let rec = try! db.searchIngredients(matching: "chicken")
            let recip = try! db.getRecipes(byIngredients: rec)
            print("hello")
        }
        
    }
}

#Preview("IngredientsInputView") {
    IngredientsInputView(viewModel: .init())
}
