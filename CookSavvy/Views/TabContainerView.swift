//
//  TabContainerView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct TabContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.appContainer) private var container

    var body: some View {
        TabView {
            coordinator.ingredientsCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: "carrot")
                    Text("Ingredients")
                }

            coordinator.recentRecipesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: "clock")
                    Text("Recent")
                }

            coordinator.favoritesCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: "heart")
                    Text("Favorites")
                }

            coordinator.settingsCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

#Preview {
    TabContainerView(coordinator: AppCoordinator())
}
