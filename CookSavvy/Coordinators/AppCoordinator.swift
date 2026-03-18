//
//  AppCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {

    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    private var _discoverCoordinator: DiscoverCoordinator?
    private var _journeyCoordinator: JourneyCoordinator?
    private var _settingsCoordinator: SettingsCoordinator?
    
    func discoverCoordinator(container: AppContainer) -> DiscoverCoordinator {
        if let existing = _discoverCoordinator { return existing }
        let coordinator = DiscoverCoordinator(container: container)
        _discoverCoordinator = coordinator
        return coordinator
    }
    
    func journeyCoordinator(container: AppContainer) -> JourneyCoordinator {
        if let existing = _journeyCoordinator { return existing }
        let settings = settingsCoordinator(container: container)
        let coordinator = JourneyCoordinator(container: container, settingsCoordinator: settings)
        _journeyCoordinator = coordinator
        return coordinator
    }
    
    private func settingsCoordinator(container: AppContainer) -> SettingsCoordinator {
        if let existing = _settingsCoordinator { return existing }
        let coordinator = SettingsCoordinator(container: container)
        _settingsCoordinator = coordinator
        return coordinator
    }
    
    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(
            analyticsService: AppContainer.shared.analyticsService,
            onComplete: { [weak self] in
                self?.hasCompletedOnboarding = true
            }
        )
    }

    func start() -> some View {
        TabContainerView(coordinator: self)
    }
}
