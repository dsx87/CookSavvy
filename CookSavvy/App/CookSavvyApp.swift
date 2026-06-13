//
//  CookSavvyApp.swift
//  CookSavvy
//
//  Created by Igor Pivnyk on 29/04/2025.
//

import SwiftUI

/// The SwiftUI application entry point.
@main
struct CookSavvyApp: App {
    var body: some Scene {
        WindowGroup {
            ThemedAppRoot()
        }
    }
}

/// Root view that bootstraps the app, applies theming, and handles startup errors.
///
/// This view handles all startup complexity: it detects UI test mode, applies an onboarding
/// migration for users upgrading from pre-onboarding builds, and presents a blocking error
/// screen if the container fails to initialize.
private struct ThemedAppRoot: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ThemePreference.storageKey) private var themePreferenceRawValue = ThemePreference.defaultValue.rawValue
    @State private var startupState: StartupState

    /// Initializes the app container and coordinator, branching between UI test mode and normal launch.
    ///
    /// In DEBUG builds, if `--uitesting` is present in launch arguments, the container is
    /// configured with mocked services and seeded test data. In all other cases the production
    /// container is initialized. Any thrown error transitions the view to the `.failed` state,
    /// rendering a blocking error screen instead of a partially initialized UI.
    init() {
        // Start crash reporting as early as possible so unhandled crashes during startup are
        // captured (handled container-init failures are captured explicitly in the catch below).
        // No-op in DEBUG and when no DSN is set.
        SentryCrashReportingService.bootstrapIfConfigured()
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
            // A thrown container-init failure is handled (not a crash), so Sentry would not see it
            // automatically. Capture it explicitly before showing the blocking error screen so
            // RELEASE startup failures (e.g. DBInterface() throwing) surface in the dashboard.
            SentryCrashReportingService().record(error)
            _startupState = State(initialValue: .failed(error))
        }
    }

    /// Resolves the active `ThemePreference` from the persisted raw value.
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

    /// Dispatches scene-activation work (auth refresh, subscription refresh) to the container.
    private func handleSceneBecameActive() async {
        guard case .ready(let container, _) = startupState else { return }
        await container.handleSceneBecameActive()
    }

    /// Migrates existing users to the onboarding-completed state on first launch after the
    /// onboarding feature was introduced.
    ///
    /// If the `hasCompletedOnboarding` key is absent from UserDefaults (meaning the app
    /// predates onboarding) and a database file already exists on disk, the user is treated as
    /// having completed onboarding so they are not shown the walkthrough again.
    private static func applyOnboardingMigrationIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: "hasCompletedOnboarding") == nil else { return }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dbURL = appSupport?.appendingPathComponent("CookSavvy/db.sqlite")
        if let dbURL, FileManager.default.fileExists(atPath: dbURL.path) {
            defaults.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    /// Tracks whether app startup succeeded or failed during container initialization.
    private enum StartupState {
        /// The container and coordinator are ready to drive the UI.
        case ready(AppContainer, AppCoordinator)
        /// Container initialization failed; the associated error is shown to the user.
        case failed(Error)
    }
}

/// The fully-initialized app UI shown when startup succeeds.
///
/// Injects shared environment values and routes between onboarding and the main tab interface.
private struct ReadyAppView: View {
    let container: AppContainer
    var coordinator: AppCoordinator

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

/// A blocking full-screen error view shown when the app container fails to initialize.
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
