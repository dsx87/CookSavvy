//
//  TabContainerView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct TabContainerView: View {
    @EnvironmentObject var container: AppContainer

    var body: some View {
        TabView {
            IngredientsInputView(
                viewModel: IngredientsInputViewModel(
                    ingredientsService: container.ingredientsService,
                    userDataService: container.userDataService
                )
            )
            .tabItem {
                Image(systemName: "carrot")
                Text("Ingredients")
            }

            RecentRecipesView(
                userDataService: container.userDataService,
                imageService: container.imageService
            )
            .tabItem {
                Image(systemName: "clock")
                Text("Recent")
            }

            FavoritesView(
                userDataService: container.userDataService,
                imageService: container.imageService
            )
            .tabItem {
                Image(systemName: "heart")
                Text("Favorites")
            }

            SettingsView(
                userDataService: container.userDataService,
                dbInterface: container.dbInterface
            )
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
    }
}

#Preview {
    TabContainerView()
        .environmentObject(AppContainer())
}
