//
//  AppCoordinator.swift
//  CookSavvy
//

import SwiftUI

/// Root coordinator that owns the two tab-level child coordinators and manages the
/// transition between onboarding and the main tab interface.
///
/// `AppCoordinator` is created once by `ThemedAppRoot` after the `AppContainer` is
/// initialized. It exposes `hasCompletedOnboarding` as a `@Published` property so the
/// root view can reactively switch between the onboarding flow and `TabContainerView`.
/// Child coordinators are created lazily on first access and cached for the lifetime
/// of the app.
@MainActor
final class AppCoordinator: ObservableObject {

    /// Whether the user has finished the first-launch onboarding walkthrough.
    ///
    /// Initialized from `UserDefaults` and written back when onboarding completes.
    /// Changing this value drives the root view's coordinator-based routing.
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    private let container: AppContainer
    /// Ingredients passed from a successful onboarding camera scan to the Discover tab.
    ///
    /// Stored here between onboarding completion and the first creation of
    /// `DiscoverCoordinator` so they can be forwarded as initial selection state.
    private var pendingOnboardingIngredients: [Ingredient]?

    private var _discoverCoordinator: DiscoverCoordinator?
    private var _journeyCoordinator: JourneyCoordinator?
    private var _settingsCoordinator: SettingsCoordinator?

    /// - Parameter container: The shared app DI container.
    init(container: AppContainer) {
        self.container = container
    }

    /// Returns the shared `DiscoverCoordinator`, creating it on first access.
    ///
    /// Passes any pending onboarding ingredients (from a successful camera scan) as the
    /// initial ingredient selection for the Discover tab, then clears them.
    func discoverCoordinator() -> DiscoverCoordinator {
        if let existing = _discoverCoordinator { return existing }
        let coordinator = DiscoverCoordinator(
            container: container,
            initialIngredients: consumeOnboardingIngredients()
        )
        _discoverCoordinator = coordinator
        return coordinator
    }

    /// Returns the shared `JourneyCoordinator`, creating it on first access.
    func journeyCoordinator() -> JourneyCoordinator {
        if let existing = _journeyCoordinator { return existing }
        let settings = settingsCoordinator()
        let coordinator = JourneyCoordinator(container: container, settingsCoordinator: settings)
        _journeyCoordinator = coordinator
        return coordinator
    }

    /// Returns the shared `SettingsCoordinator`, creating it on first access.
    private func settingsCoordinator() -> SettingsCoordinator {
        if let existing = _settingsCoordinator { return existing }
        let coordinator = SettingsCoordinator(container: container)
        _settingsCoordinator = coordinator
        return coordinator
    }

    /// Creates and returns a new `OnboardingViewModel` wired to complete onboarding.
    ///
    /// On completion, any detected ingredients are stored as `pendingOnboardingIngredients`
    /// and `hasCompletedOnboarding` is set to `true`, triggering the transition to the
    /// main tab interface.
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            analyticsService: container.analyticsService,
            ingredientDetectionService: container.ingredientDetectionService,
            cameraScanTracker: container.cameraScanTracker,
            onComplete: { [weak self] ingredients in
                self?.pendingOnboardingIngredients = ingredients.isEmpty ? nil : ingredients
                self?.hasCompletedOnboarding = true
            }
        )
    }

    /// Returns and clears the pending onboarding ingredients in one atomic operation.
    ///
    /// Called by `discoverCoordinator()` to hand off ingredients captured during
    /// onboarding. Subsequent calls return `nil` until a new onboarding session completes.
    func consumeOnboardingIngredients() -> [Ingredient]? {
        defer { pendingOnboardingIngredients = nil }
        return pendingOnboardingIngredients
    }

    /// Builds the root tab container view that hosts both feature coordinators.
    func start() -> some View {
        TabContainerView(coordinator: self)
    }
}
