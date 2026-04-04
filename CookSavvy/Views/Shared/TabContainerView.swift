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
            discoverTab
            journeyTab
        }
        .tint(theme.accent)
    }

    private var discoverTab: some View {
        coordinator.discoverCoordinator(container: container).start()
            .tabItem {
                Image(systemName: Icons.Tab.discover)
                Text(Strings.Tab.discover)
            }
            .accessibilityIdentifier(AccessibilityID.Tab.discover)
    }

    private var journeyTab: some View {
        coordinator.journeyCoordinator(container: container).start()
            .tabItem {
                Image(systemName: Icons.Tab.myKitchen)
                Text(Strings.Tab.journey)
            }
            .accessibilityIdentifier(AccessibilityID.Tab.journey)
    }
}

#Preview {
    TabContainerView(coordinator: AppCoordinator())
}
