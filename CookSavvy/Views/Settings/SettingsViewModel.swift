//
//  SettingsViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI
import Combine

private enum SettingsViewModelConstants {
    static let unknownValue = "Unknown"
    static let manageSubscriptionURL = "https://apps.apple.com/account/subscriptions"
    static let recentRecipeStatsLimit = 1000
}

@MainActor
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var currentPlan: SubscriptionPlan = .free
    @Published var recipeCount: Int = 0
    @Published var favoriteCount: Int = 0
    @Published var recentRecipeCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var showClearRecentAlert: Bool = false
    @Published var showClearFavoritesAlert: Bool = false
    @Published var isRestoringPurchases: Bool = false
    @Published var restoreError: String?
    @Published var errorMessage: String?
    @Published var themePreference: ThemePreference = .defaultValue

    // MARK: - Properties

    let appVersion: String
    let buildNumber: String

    private let userDataService: UserDataServiceProtocol
    private let dbInterface: DBInterfaceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let dietaryPreferences: DietaryPreferencesProtocol
    private let logger: any LoggerProtocol
    private weak var coordinator: SettingsCoordinator?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        userDataService: UserDataServiceProtocol,
        dbInterface: DBInterfaceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        dietaryPreferences: DietaryPreferencesProtocol,
        logger: any LoggerProtocol,
        coordinator: SettingsCoordinator?
    ) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface
        self.subscriptionService = subscriptionService
        self.dietaryPreferences = dietaryPreferences
        self.logger = logger
        self.coordinator = coordinator

        // Get app version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.appVersion = version
        } else {
            self.appVersion = SettingsViewModelConstants.unknownValue
        }

        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.buildNumber = build
        } else {
            self.buildNumber = SettingsViewModelConstants.unknownValue
        }
        
        subscriptionService.currentPlanPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] plan in
                self?.currentPlan = plan
            }
            .store(in: &cancellables)
        
        currentPlan = subscriptionService.currentPlan
        themePreference = userDataService.getThemePreference()
    }
    
    func showUpgrade() {
        coordinator?.showUpgrade()
    }
    
    func restorePurchases() async {
        isRestoringPurchases = true
        restoreError = nil
        defer { isRestoringPurchases = false }
        
        do {
            try await subscriptionService.restorePurchases()
        } catch {
            restoreError = error.localizedDescription
        }
    }
    
    func updateThemePreference(_ themePreference: ThemePreference) {
        guard self.themePreference != themePreference else { return }
        self.themePreference = themePreference
        userDataService.setThemePreference(themePreference)
    }

    func isDietaryRestrictionActive(_ restriction: DietaryRestriction) -> Bool {
        dietaryPreferences.isActive(restriction)
    }

    func toggleDietaryRestriction(_ restriction: DietaryRestriction) {
        dietaryPreferences.toggle(restriction)
    }

    // TODO: check the link
    func openManageSubscriptions() {
        if let url = URL(string: SettingsViewModelConstants.manageSubscriptionURL) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Public Methods

    func loadSettings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Load database stats
            recipeCount = try await getRecipeCount()
            favoriteCount = try await getFavoriteCount()
            recentRecipeCount = try await getRecentRecipeCount()
        } catch {
            logger.error("Failed to load settings: \(String(describing: error))")
            errorMessage = Strings.Errors.settingsLoadFailed
        }
    }

    func clearRecentData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await userDataService.clearRecentData()
            // Reload stats
            await loadSettings()
        } catch {
            logger.error("Failed to clear recent data: \(String(describing: error))")
            errorMessage = Strings.Errors.clearDataFailed
        }
    }

    func clearFavorites() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await userDataService.clearFavorites()
            // Reload stats
            await loadSettings()
        } catch {
            logger.error("Failed to clear favorites: \(String(describing: error))")
            errorMessage = Strings.Errors.clearDataFailed
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func getRecipeCount() async throws -> Int {
        return try dbInterface.getRecipeCount()
    }

    private func getFavoriteCount() async throws -> Int {
        let favorites = try await userDataService.getFavorites()
        return favorites.count
    }

    private func getRecentRecipeCount() async throws -> Int {
        let recent = try await userDataService.getRecentRecipes(limit: SettingsViewModelConstants.recentRecipeStatsLimit)
        return recent.count
    }
}
