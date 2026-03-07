//
//  CookSavvyApp.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import SwiftUI

@main
struct CookSavvyApp: App {
    var body: some Scene {
        WindowGroup {
            ThemedAppRoot()
        }
    }
}

private struct ThemedAppRoot: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(ThemePreference.storageKey) private var themePreferenceRawValue = ThemePreference.defaultValue.rawValue
    @StateObject private var coordinator = AppCoordinator()

    private var themePreference: ThemePreference {
        ThemePreference.from(rawValue: themePreferenceRawValue)
    }

    var body: some View {
        TabContainerView(coordinator: coordinator)
            .preferredColorScheme(themePreference.preferredColorScheme)
            .environment(\.appTheme, themePreference.resolvedTheme(for: colorScheme))
    }
}
