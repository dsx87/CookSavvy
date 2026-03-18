//
//  SettingsCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class SettingsCoordinator: ObservableObject {
    
    private let container: AppContainer
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: SheetDestination?
    
    init(container: AppContainer) {
        self.container = container
    }
    
    func start() -> some View {
        SettingsCoordinatorView(coordinator: self)
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            userDataService: container.userDataService,
            dbInterface: container.dbInterface,
            subscriptionService: container.subscriptionService,
            dietaryPreferences: container.dietaryPreferences,
            coordinator: self
        )
    }
    
    func showUpgrade() {
        presentedSheet = .upgrade
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
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

extension SettingsCoordinator {
    enum SheetDestination: Identifiable {
        case upgrade
        
        var id: String {
            switch self {
            case .upgrade: return "upgrade"
            }
        }
    }
}

struct SettingsCoordinatorView: View {
    @ObservedObject var coordinator: SettingsCoordinator
    @StateObject private var viewModel: SettingsViewModel
    
    init(coordinator: SettingsCoordinator) {
        self.coordinator = coordinator
        _viewModel = StateObject(wrappedValue: coordinator.makeSettingsViewModel())
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
