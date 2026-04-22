//
//  AppCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {

    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    private let container: AppContainer
    private var pendingOnboardingIngredients: [Ingredient]?

    private var _discoverCoordinator: DiscoverCoordinator?
    private var _journeyCoordinator: JourneyCoordinator?
    private var _settingsCoordinator: SettingsCoordinator?

    init(container: AppContainer) {
        self.container = container
    }
    
    func discoverCoordinator() -> DiscoverCoordinator {
        if let existing = _discoverCoordinator { return existing }
        let coordinator = DiscoverCoordinator(
            container: container,
            initialIngredients: consumeOnboardingIngredients()
        )
        _discoverCoordinator = coordinator
        return coordinator
    }
    
    func journeyCoordinator() -> JourneyCoordinator {
        if let existing = _journeyCoordinator { return existing }
        let settings = settingsCoordinator()
        let coordinator = JourneyCoordinator(container: container, settingsCoordinator: settings)
        _journeyCoordinator = coordinator
        return coordinator
    }
    
    private func settingsCoordinator() -> SettingsCoordinator {
        if let existing = _settingsCoordinator { return existing }
        let coordinator = SettingsCoordinator(container: container)
        _settingsCoordinator = coordinator
        return coordinator
    }
    
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

    func consumeOnboardingIngredients() -> [Ingredient]? {
        defer { pendingOnboardingIngredients = nil }
        return pendingOnboardingIngredients
    }

    func start() -> some View {
        TabContainerView(coordinator: self)
    }
}
