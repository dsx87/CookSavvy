//
//  IngredientsInputView.swift
//  CookSavvy
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputView: View {
    @ObservedObject var viewModel: IngredientsInputViewModel

    var body: some View {
        Group {
            if !viewModel.isIngredientsReady {
                loadingView
            } else {
                mainContent
            }
        }
        .navigationTitle(UIConstants.ingredientsInputNavigationTitle)
        .popover(isPresented: $viewModel.cameraViewPresented, content: {
            Text(UIConstants.ingredientsInputCameraPlaceholderText)
                .presentationCompactAdaptation(.fullScreenCover)
                .onTapGesture {
                    viewModel.cameraViewPresented = false
                }
        })
    }
    
    private var loadingView: some View {
        VStack(spacing: UIConstants.statusStackSpacing) {
            ProgressView()
                .scaleEffect(UIConstants.statusProgressScale)
            Text(UIConstants.ingredientsInputLoadingText)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(content: {
            RoundedRectangle(cornerRadius: UIConstants.ingredientsInputBackgroundCornerRadius)
                .foregroundStyle(Color.backOrange2)
                .ignoresSafeArea()
        })
    }
    
    private var mainContent: some View {
        VStack(spacing: UIConstants.mainContentStackSpacing) {
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
                        ProgressView(UIConstants.ingredientsInputSearchLoadingText)
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
                .frame(width: UIConstants.ingredientsPopoverWidth, height: UIConstants.ingredientsPopoverHeight)
                .padding()
                .presentationCompactAdaptation(.popover)
            }
            
            IngredientsInputSelectedIngredients(ingredientsNames: $viewModel.selectedIngredients)
            IngredientsInputFastIngredientSelector(
                fastIngredients: viewModel.fastSelectorIngredients,
                selectedIngredients: $viewModel.selectedIngredients
            )
            Spacer(minLength: UIConstants.ingredientsFindButtonSpacerMinLength)
            IngredientsInputFindRecipesButton(ingredientsNumber: viewModel.selectedIngredients.count) {
                Task {
                    await viewModel.onFindRecipes()
                }
                viewModel.navigateToRecipesResult()
            }
        }
        .padding()
        .background(content: {
            RoundedRectangle(cornerRadius: UIConstants.ingredientsInputBackgroundCornerRadius)
                .foregroundStyle(Color.backOrange2)
                .ignoresSafeArea()
        })
    }
}

#Preview("IngredientsInputView") {
    let container = AppContainer.shared
    return IngredientsInputView(
        viewModel: IngredientsInputViewModel(
            ingredientsService: container.ingredientsService,
            userDataService: container.userDataService,
            databaseInitService: container.databaseInitService,
            coordinator: nil
        )
    )
}
