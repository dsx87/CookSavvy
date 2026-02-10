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
                    Image(systemName: Icons.Tab.ingredients)
                    Text(Strings.Tab.ingredients)
                }

            coordinator.recentRecipesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: Icons.Tab.recent)
                    Text(Strings.Tab.recent)
                }

            coordinator.favoritesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: Icons.Tab.favorites)
                    Text(Strings.Tab.favorites)
                }

            coordinator.settingsCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: Icons.Tab.settings)
                    Text(Strings.Tab.settings)
                }
        }
    }
}

#Preview {
    TabContainerView(coordinator: AppCoordinator())
}
