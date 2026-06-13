//
//  SettingsCoordinator.swift
//  CookSavvy
//

import SwiftUI

/// Coordinator for the Settings screen, managing the settings view and upgrade sheet presentation.
///
/// `SettingsCoordinator` is a child of `AppCoordinator`, shared between the standalone
/// `SettingsCoordinatorView` (used when Settings is its own navigation root) and
/// `JourneySettingsDestination` (used when Settings is pushed within the Journey stack).
@MainActor
@Observable final class SettingsCoordinator {

    private let container: AppContainer
    /// Navigation stack path (reserved for future settings sub-screens).
    var navigationPath = NavigationPath()
    /// The currently presented sheet destination, if any.
    var presentedSheet: SheetDestination?

    /// - Parameter container: The shared app DI container.
    init(container: AppContainer) {
        self.container = container
    }

    /// Builds and returns the root coordinator view for Settings.
    func start() -> some View {
        SettingsCoordinatorView(coordinator: self)
    }

    /// Creates a `SettingsViewModel` wired to this coordinator for navigation callbacks.
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            userDataService: container.userDataService,
            dbInterface: container.dbInterface,
            subscriptionService: container.subscriptionService,
            dietaryPreferences: container.dietaryPreferences,
            authService: container.authService,
            analyticsService: container.analyticsService,
            signInWithAppleAction: container.signInWithAppleAction,
            logger: container.loggingService.makeLogger(category: .settingsViewModel),
            coordinator: self
        )
    }
    
    /// Presents the upgrade sheet.
    func showUpgrade() {
        presentedSheet = .upgrade
    }

    /// Dismisses the active sheet.
    func dismissSheet() {
        presentedSheet = nil
    }

    /// Creates an `UpgradeViewModel` that dismisses the sheet on completion.
    func makeUpgradeViewModel() -> UpgradeViewModel {
        UpgradeViewModel(
            subscriptionService: container.subscriptionService,
            analyticsService: container.analyticsService,
            onDismiss: { [weak self] in
                self?.dismissSheet()
            }
        )
    }
}

/// Destination enums owned by ``SettingsCoordinator``.
extension SettingsCoordinator {
    /// Sheet destinations presented from the Settings screen.
    enum SheetDestination: Identifiable {
        /// CookSavvy+ upgrade prompt.
        case upgrade

        var id: String {
            switch self {
            case .upgrade: return "upgrade"
            }
        }
    }
}

/// Internal SwiftUI coordinator view that hosts the Settings navigation stack and applies
/// sheet presentations driven by `SettingsCoordinator`.
struct SettingsCoordinatorView: View {
    @Bindable var coordinator: SettingsCoordinator
    @State private var viewModel: SettingsViewModel
    
    /// Creates the coordinator view and pins the settings view model as a state object.
    init(coordinator: SettingsCoordinator) {
        self.coordinator = coordinator
        _viewModel = State(wrappedValue: coordinator.makeSettingsViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(item: $coordinator.presentedSheet) { sheet in
            switch sheet {
            case .upgrade:
                UpgradeView(viewModel: coordinator.makeUpgradeViewModel())
            }
        }
    }
}
