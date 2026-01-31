//
//  IngredientsCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class IngredientsCoordinator: ObservableObject {
    
    private let container: AppContainer
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: SheetDestination?
    
    init(container: AppContainer) {
        self.container = container
    }
    
    func start() -> some View {
        IngredientsCoordinatorView(coordinator: self)
    }
    
    func makeIngredientsInputViewModel() -> IngredientsInputViewModel {
        IngredientsInputViewModel(
            ingredientsService: container.ingredientsService,
            userDataService: container.userDataService,
            databaseInitService: container.databaseInitService,
            ingredientDetectionService: container.ingredientDetectionService,
            subscriptionService: container.subscriptionService,
            coordinator: self
        )
    }
    
    func makeRecipesResultViewModel(selectedIngredients: Set<Ingredient>) -> RecipesResultViewModel {
        RecipesResultViewModel(
            selectedIngredients: selectedIngredients,
            recipeService: container.recipeService,
            imageService: container.imageService,
            databaseInitService: container.databaseInitService,
            userDataService: container.userDataService,
            subscriptionService: container.subscriptionService,
            coordinator: self
        )
    }
    
    func makeRecipeDetailsViewModel(recipe: Recipe) -> RecipeDetailsViewModel {
        RecipeDetailsViewModel(
            recipe: recipe,
            userDataService: container.userDataService
        )
    }
    
    func makeCameraViewModel(
        onDismiss: @escaping () -> Void,
        onIngredientsDetected: @escaping ([Ingredient]) -> Void
    ) -> CameraViewModel {
        CameraViewModel(
            detectionService: container.ingredientDetectionService,
            onDismiss: onDismiss,
            onIngredientsDetected: onIngredientsDetected
        )
    }
    
    func showRecipesResult() {
        navigationPath.append(NavigationDestination.recipesResult)
    }
    
    func showRecipeDetails(recipe: Recipe) {
        navigationPath.append(NavigationDestination.recipeDetails(recipe))
    }
    
    func goBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
    
    func showUpgrade() {
        presentedSheet = .upgrade
    }
    
    func makeUpgradeViewModel() -> UpgradeViewModel {
        UpgradeViewModel(
            subscriptionService: container.subscriptionService,
            onDismiss: { [weak self] in
                self?.dismissSheet()
            }
        )
    }
    
    func showCamera() {
        presentedSheet = .camera
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
}

extension IngredientsCoordinator {
    enum NavigationDestination: Hashable {
        case recipesResult
        case recipeDetails(Recipe)
    }
    
    enum SheetDestination: Identifiable {
        case camera
        case upgrade
        
        var id: String {
            switch self {
            case .camera: return "camera"
            case .upgrade: return "upgrade"
            }
        }
    }
}

struct IngredientsCoordinatorView: View {
    @ObservedObject var coordinator: IngredientsCoordinator
    @StateObject private var viewModel: IngredientsInputViewModel
    
    init(coordinator: IngredientsCoordinator) {
        self.coordinator = coordinator
        _viewModel = StateObject(wrappedValue: coordinator.makeIngredientsInputViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            IngredientsInputView(viewModel: viewModel)
                .navigationDestination(for: IngredientsCoordinator.NavigationDestination.self) { destination in
                    switch destination {
                    case .recipesResult:
                        RecipesResultView(
                            viewModel: coordinator.makeRecipesResultViewModel(
                                selectedIngredients: viewModel.selectedIngredients
                            )
                        )
                    case .recipeDetails(let recipe):
                        RecipeDetailsView(
                            viewModel: coordinator.makeRecipeDetailsViewModel(recipe: recipe)
                        )
                    }
                }
        }
        .fullScreenCover(item: Binding(
            get: { coordinator.presentedSheet == .camera ? coordinator.presentedSheet : nil },
            set: { if $0 == nil { coordinator.dismissSheet() } }
        )) { _ in
            CameraView(
                viewModel: coordinator.makeCameraViewModel(
                    onDismiss: { coordinator.dismissSheet() },
                    onIngredientsDetected: { viewModel.addDetectedIngredients($0) }
                )
            )
        }
        .sheet(item: Binding(
            get: { coordinator.presentedSheet == .upgrade ? coordinator.presentedSheet : nil },
            set: { if $0 == nil { coordinator.dismissSheet() } }
        )) { _ in
            UpgradeView(viewModel: coordinator.makeUpgradeViewModel())
        }
    }
}
