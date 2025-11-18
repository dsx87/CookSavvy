//
//  IngredientsInputView.swift
//  CookSavvy
//  Created by Igor Pivnyk on 28/06/2025.
//

import SwiftUI

@MainActor
final class IngredientsInputViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var ingredients: [Ingredient] = []
    @Published var searchText: String = "" {
        didSet {
            handleSearchTextChange(searchText)
        }
    }
    @Published var selectedIngredients: Set<Ingredient> = []
    @Published var cameraViewPresented: Bool = false
    @Published var navigationPath: NavigationPath = NavigationPath()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    
    let navigationTitle = "Ingredients Input"
    
    private let ingredientsService: IngredientsService
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(ingredientsService: IngredientsService) {
        self.ingredientsService = ingredientsService
        
        // Pre-load ingredients on initialization
        Task {
            try? await ingredientsService.ensureIngredientsLoaded()
        }
    }
    
    // MARK: - Public Methods
    
    func autocompletionDidHide() {
        clearText()
    }
    
    func selectIngredient(_ ingredient: Ingredient) {
        // Prevent duplicates
        guard !selectedIngredients.contains(ingredient) else {
            return
        }
        selectedIngredients.insert(ingredient)
    }
    
    func deselectIngredient(_ ingredient: Ingredient) {
        selectedIngredients.remove(ingredient)
    }
    
    func toggleIngredient(_ ingredient: Ingredient) {
        if selectedIngredients.contains(ingredient) {
            deselectIngredient(ingredient)
        } else {
            selectIngredient(ingredient)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSearchTextChange(_ query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            ingredients = []
            isLoading = false
            return
        }
        
        searchTask = Task {
            await searchIngredients(query)
        }
    }
    
    private func searchIngredients(_ query: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Add small delay for debouncing
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            // Check if task was cancelled
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            
            let results = try await ingredientsService.searchFullIngredients(
                matching: query,
                limit: 20
            )
            
            ingredients = results
            isLoading = false
        } catch is CancellationError {
            // Task was cancelled - this is expected, don't show error
            ingredients = []
            isLoading = false
        } catch {
            // Actual error occurred
            ingredients = []
            isLoading = false
            errorMessage = "Failed to search ingredients: \(error.localizedDescription)"
        }
    }
    
    private func clearText() {
        searchText = ""
    }
    
    // MARK: - Cleanup
    
    deinit {
        searchTask?.cancel()
    }
}

struct IngredientsInputView: View {
    @StateObject var viewModel: IngredientsInputViewModel
    
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
                Text("not implemented yet, close")
                    .presentationCompactAdaptation(.fullScreenCover)
                    .onTapGesture {
                        viewModel.cameraViewPresented = false
                    }
            })
        }
    }
}

#Preview("IngredientsInputView") {
    IngredientsInputView(
        viewModel: IngredientsInputViewModel(
            ingredientsService: IngredientsService()
        )
    )
}
