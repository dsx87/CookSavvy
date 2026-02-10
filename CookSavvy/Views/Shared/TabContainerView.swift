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
                    Image(systemName: UI.Tab.ingredientsIcon)
                    Text(UI.Tab.ingredientsTitle)
                }

            coordinator.recentRecipesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: UI.Tab.recentIcon)
                    Text(UI.Tab.recentTitle)
                }

            coordinator.favoritesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: UI.Tab.favoritesIcon)
                    Text(UI.Tab.favoritesTitle)
                }

            coordinator.settingsCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: UI.Tab.settingsIcon)
                    Text(UI.Tab.settingsTitle)
                }
        }
    }
}

#Preview {
    TabContainerView(coordinator: AppCoordinator())
}
