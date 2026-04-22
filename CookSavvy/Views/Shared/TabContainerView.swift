//
//  TabContainerView.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 12/07/2025.
//

import SwiftUI

/// The root tab-bar container that hosts the two main app tabs — Discover and My Kitchen.
///
/// Owned and driven by `AppCoordinator`, which lazily vends the per-tab coordinators.
/// The accent colour is bound to the active theme so the tab bar tint updates dynamically.
struct TabContainerView: View {
    @ObservedObject var coordinator: AppCoordinator
    @Environment(\.appTheme) var theme
    
    var body: some View {
        TabView {
            discoverTab
            journeyTab
        }
        .tint(theme.accent)
    }

    /// The Discover tab item wrapping the `DiscoverCoordinator` navigation stack.
    private var discoverTab: some View {
        coordinator.discoverCoordinator().start()
            .tabItem {
                Image(systemName: Icons.Tab.discover)
                Text(Strings.Tab.discover)
            }
            .accessibilityIdentifier(AccessibilityID.Tab.discover)
    }

    /// The My Kitchen tab item wrapping the `JourneyCoordinator` navigation stack.
    private var journeyTab: some View {
        coordinator.journeyCoordinator().start()
            .tabItem {
                Image(systemName: Icons.Tab.myKitchen)
                Text(Strings.Tab.journey)
            }
            .accessibilityIdentifier(AccessibilityID.Tab.journey)
    }
}

#Preview {
    if let container = try? AppContainer() {
        TabContainerView(coordinator: AppCoordinator(container: container))
    }
}
