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
    @StateObject private var coordinator: AppCoordinator

    init() {
        #if DEBUG
        let uiTestConfig = UITestConfiguration.fromLaunchArguments()
        if uiTestConfig.isUITesting {
            AppContainer.configureForUITesting(uiTestConfig)
            uiTestConfig.prepareDefaults()
            _coordinator = StateObject(wrappedValue: AppCoordinator())
            return
        }
        #endif

        Self.applyOnboardingMigrationIfNeeded()
        _coordinator = StateObject(wrappedValue: AppCoordinator())
    }

    private var themePreference: ThemePreference {
        ThemePreference.from(rawValue: themePreferenceRawValue)
    }

    var body: some View {
        Group {
            if coordinator.hasCompletedOnboarding {
                coordinator.start()
            } else {
                OnboardingView(viewModel: coordinator.makeOnboardingViewModel())
            }
        }
        .preferredColorScheme(themePreference.preferredColorScheme)
        .environment(\.appTheme, themePreference.resolvedTheme(for: colorScheme))
    }

    private static func applyOnboardingMigrationIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: "hasCompletedOnboarding") == nil else { return }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dbURL = appSupport?.appendingPathComponent("CookSavvy/db.sqlite")
        if let dbURL, FileManager.default.fileExists(atPath: dbURL.path) {
            defaults.set(true, forKey: "hasCompletedOnboarding")
        }
    }
}
