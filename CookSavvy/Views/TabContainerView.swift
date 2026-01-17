//
//  TabContainerView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct TabContainerView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        TabView {
            coordinator.ingredientsCoordinator.start()
                .tabItem {
                    Image(systemName: "carrot")
                    Text("Ingredients")
                }

            coordinator.recentRecipesCoordinator.start()
                .tabItem {
                    Image(systemName: "clock")
                    Text("Recent")
                }

            coordinator.favoritesCoordinator.start()
                .tabItem {
                    Image(systemName: "heart")
                    Text("Favorites")
                }

            coordinator.settingsCoordinator.start()
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
