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

    init() {
        // Migration: existing installs that predate the onboarding key should skip it.
        // If the DB file already exists the app has been used before, so mark onboarding done.
        guard UserDefaults.standard.object(forKey: "hasCompletedOnboarding") == nil else { return }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dbURL = appSupport?.appendingPathComponent("CookSavvy/db.sqlite")
        if let dbURL, FileManager.default.fileExists(atPath: dbURL.path) {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
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
}
