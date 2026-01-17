//
//  SettingsCoordinator.swift
//  CookSavvy
//

import SwiftUI

@MainActor
final class SettingsCoordinator: ObservableObject {
    
    private let container: AppContainer
    @Published var navigationPath = NavigationPath()
    
    init(container: AppContainer) {
        self.container = container
    }
    
    func start() -> some View {
        SettingsCoordinatorView(coordinator: self)
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            userDataService: container.userDataService,
            dbInterface: container.dbInterface
        )
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
    }
}
