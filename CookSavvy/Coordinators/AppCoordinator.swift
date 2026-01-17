//
//  AppCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    
    let container: AppContainer
    
    lazy var ingredientsCoordinator: IngredientsCoordinator = {
        IngredientsCoordinator(container: container)
    }()
    
    lazy var recentRecipesCoordinator: RecentRecipesCoordinator = {
        RecentRecipesCoordinator(container: container)
    }()
    
    lazy var favoritesCoordinator: FavoritesCoordinator = {
        FavoritesCoordinator(container: container)
    }()
    
    lazy var settingsCoordinator: SettingsCoordinator = {
        SettingsCoordinator(container: container)
    }()
    
    init(container: AppContainer) {
        self.container = container
    }
    
    convenience init() {
        self.init(container: AppContainer())
    }
    
    func start() -> some View {
        TabContainerView(coordinator: self)
    }
}
