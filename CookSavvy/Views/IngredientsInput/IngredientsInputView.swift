//
//  IngredientsInputView.swift
//  CookSavvy
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

struct IngredientsInputView: View {
    @ObservedObject var viewModel: IngredientsInputViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if !viewModel.isIngredientsReady {
                loadingView
            } else {
                mainContent
            }
        }
        .navigationTitle(Strings.IngredientsInput.navigationTitle)
    }
    
    private var loadingView: some View {
        VStack(spacing: UI.Common.stackSpacing) {
            ProgressView()
                .scaleEffect(UI.Common.progressScale)
            Text(Strings.IngredientsInput.loading)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(content: {
            RoundedRectangle(cornerRadius: UI.IngredientsInput.backgroundCornerRadius)
                .foregroundStyle(theme.backgroundSecondary)
                .ignoresSafeArea()
        })
    }
    
    private var mainContent: some View {
        VStack(spacing: UI.Common.contentSpacing) {
            IngredientsInputSearchBar(
                selectedIngredients: $viewModel.selectedIngredients,
                onCameraTapped: { viewModel.handleCameraTap() },
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
                        ProgressView(Strings.IngredientsInput.searchLoading)
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
                .frame(width: UI.IngredientsInput.popoverWidth, height: UI.IngredientsInput.popoverHeight)
                .padding()
                .presentationCompactAdaptation(.popover)
            }
            
            IngredientsInputSelectedIngredients(ingredientsNames: $viewModel.selectedIngredients)
            IngredientsInputFastIngredientSelector(
                fastIngredients: viewModel.fastSelectorIngredients,
                selectedIngredients: $viewModel.selectedIngredients
            )
            Spacer(minLength: UI.IngredientsInput.findButtonSpacerMinLength)
            IngredientsInputFindRecipesButton(ingredientsNumber: viewModel.selectedIngredients.count) {
                Task {
                    await viewModel.onFindRecipes()
                }
                viewModel.navigateToRecipesResult()
            }
        }
        .padding()
        .background(content: {
            RoundedRectangle(cornerRadius: UI.IngredientsInput.backgroundCornerRadius)
                .foregroundStyle(theme.backgroundSecondary)
                .ignoresSafeArea()
        })
    }
}

#Preview("IngredientsInputView") {
    let container = AppContainer.shared
    IngredientsInputView(
        viewModel: IngredientsInputViewModel(
            ingredientsService: container.ingredientsService,
            userDataService: container.userDataService,
            databaseInitService: container.databaseInitService,
            ingredientDetectionService: container.ingredientDetectionService,
            subscriptionService: container.subscriptionService,
            coordinator: nil
        )
    )
}
