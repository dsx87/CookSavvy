//
//  TabContainerView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

struct TabContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.appTheme) var theme
    var container: AppContainer { AppContainer.shared }
    
    var body: some View {
        TabView {
            coordinator.discoverCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: Icons.Tab.discover)
                    Text(Strings.Tab.discover)
                }

            coordinator.journeyCoordinator(container: container).start()
                .tabItem {
                    Image(systemName: Icons.Tab.journey)
                    Text(Strings.Tab.journey)
                }
        }
        .tint(theme.accent)
    }
}

#Preview {
    TabContainerView(coordinator: AppCoordinator())
}
