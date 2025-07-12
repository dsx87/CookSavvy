//
//  TabContainerView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct TabContainerView: View {
    var body: some View {
        TabView {
            IngredientsInputView()
                .tabItem {
                    Image(systemName: "carrot")
                    Text("Ingredients")
                }
            RecipesResultView(selectedIngredients: ["Pasta, Basta, Something"])
                .tabItem {
                    Image(systemName: "clock")
                    Text("Recent Search")
                }
            RecipesResultView(selectedIngredients: ["Pasta, Basta, Something"])
                .tabItem {
                    Image(systemName: "fork.knife.circle")
                    Text("Recent Dishes")
                }
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

#Preview {
    TabContainerView()
}
