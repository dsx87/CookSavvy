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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ThemePreference.storageKey) private var themePreferenceRawValue = ThemePreference.defaultValue.rawValue
    @State private var startupState: StartupState

    init() {
        do {
            #if DEBUG
            let uiTestConfig = UITestConfiguration.fromLaunchArguments()
            if uiTestConfig.isUITesting {
                let container = try AppContainer.configureForUITesting(uiTestConfig)
                uiTestConfig.prepareDefaults()
                _startupState = State(initialValue: .ready(container, AppCoordinator(container: container)))
                return
            }
            #endif

            Self.applyOnboardingMigrationIfNeeded()
            let container = try AppContainer()
            _startupState = State(initialValue: .ready(container, AppCoordinator(container: container)))
        } catch {
            _startupState = State(initialValue: .failed(error))
        }
    }

    private var themePreference: ThemePreference {
        ThemePreference.from(rawValue: themePreferenceRawValue)
    }

    var body: some View {
        Group {
            switch startupState {
            case .ready(let container, let coordinator):
                ReadyAppView(container: container, coordinator: coordinator)
            case .failed(let error):
                StartupErrorView(error: error)
            }
        }
        .preferredColorScheme(themePreference.preferredColorScheme)
        .environment(\.appTheme, themePreference.resolvedTheme(for: colorScheme))
        .task {
            await handleSceneBecameActive()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await handleSceneBecameActive()
                }
            }
        }
    }

    private func handleSceneBecameActive() async {
        guard case .ready(let container, _) = startupState else { return }
        await container.handleSceneBecameActive()
    }

    private static func applyOnboardingMigrationIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: "hasCompletedOnboarding") == nil else { return }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dbURL = appSupport?.appendingPathComponent("CookSavvy/db.sqlite")
        if let dbURL, FileManager.default.fileExists(atPath: dbURL.path) {
            defaults.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    private enum StartupState {
        case ready(AppContainer, AppCoordinator)
        case failed(Error)
    }
}

private struct ReadyAppView: View {
    let container: AppContainer
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Group {
            if coordinator.hasCompletedOnboarding {
                coordinator.start()
            } else {
                OnboardingView(viewModel: coordinator.makeOnboardingViewModel())
            }
        }
        .environment(\.imageService, container.imageService)
        .environment(\.loggingService, container.loggingService)
    }
}

private struct StartupErrorView: View {
    @Environment(\.appTheme) private var theme
    let error: Error

    var body: some View {
        VStack(spacing: UI.Common.contentSpacing) {
            Image(systemName: Icons.Common.error)
                .font(.system(size: UI.Onboarding.stateIconSize))
                .foregroundStyle(theme.rose)
            Text(Strings.Startup.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.text1)
            Text(Strings.Startup.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.text2)
            Text(error.localizedDescription)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.text3)
        }
        .padding(UI.Common.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }
}
