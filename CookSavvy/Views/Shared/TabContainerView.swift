//
//  TabContainerView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct TabContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    var container: AppContainer { AppContainer.shared }
    
    var body: some View {
        TabView {
            coordinator.ingredientsCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: UIConstants.tabIngredientsIconName)
                    Text(UIConstants.tabIngredientsTitle)
                }

            coordinator.recentRecipesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: UIConstants.tabRecentIconName)
                    Text(UIConstants.tabRecentTitle)
                }

            coordinator.favoritesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: UIConstants.tabFavoritesIconName)
                    Text(UIConstants.tabFavoritesTitle)
                }

            coordinator.settingsCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: UIConstants.tabSettingsIconName)
                    Text(UIConstants.tabSettingsTitle)
                }
        }
    }
}

#Preview {
    TabContainerView(coordinator: AppCoordinator())
}
