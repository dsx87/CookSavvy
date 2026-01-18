//
//  AppCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    
    private var _ingredientsCoordinator: IngredientsCoordinator?
    private var _recentRecipesCoordinator: RecentRecipesCoordinator?
    private var _favoritesCoordinator: FavoritesCoordinator?
    private var _settingsCoordinator: SettingsCoordinator?
    
    func ingredientsCoordinator(container: AppContainer) -> IngredientsCoordinator {
        if let existing = _ingredientsCoordinator { return existing }
        let coordinator = IngredientsCoordinator(container: container)
        _ingredientsCoordinator = coordinator
        return coordinator
    }
    
    func recentRecipesCoordinator(container: AppContainer) -> RecentRecipesCoordinator {
        if let existing = _recentRecipesCoordinator { return existing }
        let coordinator = RecentRecipesCoordinator(container: container)
        _recentRecipesCoordinator = coordinator
        return coordinator
    }
    
    func favoritesCoordinator(container: AppContainer) -> FavoritesCoordinator {
        if let existing = _favoritesCoordinator { return existing }
        let coordinator = FavoritesCoordinator(container: container)
        _favoritesCoordinator = coordinator
        return coordinator
    }
    
    func settingsCoordinator(container: AppContainer) -> SettingsCoordinator {
        if let existing = _settingsCoordinator { return existing }
        let coordinator = SettingsCoordinator(container: container)
        _settingsCoordinator = coordinator
        return coordinator
    }
    
    func start() -> some View {
        TabContainerView(coordinator: self)
    }
}
