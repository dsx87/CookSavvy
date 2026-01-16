//
//  IngredientsInputView.swift
//  CookSavvy
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputView: View {
    @EnvironmentObject var container: AppContainer
    @StateObject var viewModel: IngredientsInputViewModel

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if !container.databaseInitService.state.isIngredientsReady {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Ingredients Input")
            .navigationDestination(for: String.self) { _ in
                RecipesResultView(
                    selectedIngredients: viewModel.selectedIngredients,
                    navigationPath: $viewModel.navigationPath,
                    recipeService: container.recipeService,
                    imageService: container.imageService,
                    databaseInitService: container.databaseInitService,
                    userDataService: container.userDataService
                )
            }
            .popover(isPresented: $viewModel.cameraViewPresented, content: {
                Text("not implemented yet, close")
                    .presentationCompactAdaptation(.fullScreenCover)
                    .onTapGesture {
                        viewModel.cameraViewPresented = false
                    }
            })
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading ingredients...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(content: {
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(Color.backOrange2)
                .ignoresSafeArea()
        })
    }
    
    private var mainContent: some View {
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
                })
            ) {
                VStack {
                    if viewModel.isLoading {
                        ProgressView("Searching...")
                            .padding()
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        IngredientsInputAutocompletion(
                            ingredients: $viewModel.ingredients,
                            selectedIngredients: $viewModel.selectedIngredients
                        )
                    }
                }
                .frame(width: 400, height: 300)
                .padding()
                .presentationCompactAdaptation(.popover)
            }
            
            IngredientsInputSelectedIngredients(ingredientsNames: $viewModel.selectedIngredients)
            IngredientsInputFastIngredientSelector(
                selectedIngredients: $viewModel.selectedIngredients,
                recentIngredients: viewModel.fastSelectorIngredients
            )
            Spacer(minLength: 150)
            IngredientsInputFindRecipesButton(disabled: viewModel.selectedIngredients.isEmpty) {
                Task {
                    await viewModel.onFindRecipes()
                }
                viewModel.navigationPath.append("RecipesResultView")
            }
        }
        .padding()
        .background(content: {
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(Color.backOrange2)
                .ignoresSafeArea()
        })
    }
}

#Preview("IngredientsInputView") {
    let container = AppContainer()
    return IngredientsInputView(
        viewModel: IngredientsInputViewModel(
            ingredientsService: container.ingredientsService,
            userDataService: container.userDataService
        )
    )
    .environmentObject(container)
}
