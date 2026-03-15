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
    @Published var localSourceEnabled: Bool = true
    @Published var apiSourceEnabled: Bool = false
    @Published var aiSourceEnabled: Bool = false
    @Published var themePreference: ThemePreference = .defaultValue

    // MARK: - Properties

    let appVersion: String
    let buildNumber: String

    private let userDataService: UserDataServiceProtocol
    private let dbInterface: DBInterfaceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private weak var coordinator: SettingsCoordinator?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        userDataService: UserDataServiceProtocol,
        dbInterface: DBInterfaceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        coordinator: SettingsCoordinator?
    ) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface
        self.subscriptionService = subscriptionService
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
        loadSourcePreferences()
        themePreference = userDataService.getThemePreference()
    }
    
    private func loadSourcePreferences() {
        let enabled = userDataService.getEnabledSources()
        localSourceEnabled = enabled.contains(.offline)
        apiSourceEnabled = enabled.contains(.online)
        aiSourceEnabled = enabled.contains(.ai)
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
    
    func toggleLocalSource() {
        localSourceEnabled = userDataService.toggleSource(.offline)
    }
    
    func toggleApiSource() {
        apiSourceEnabled = userDataService.toggleSource(.online)
    }
    
    func toggleAiSource() {
        aiSourceEnabled = userDataService.toggleSource(.ai)
    }

    var extendedRecipesEnabled: Bool {
        apiSourceEnabled || aiSourceEnabled
    }

    func toggleExtendedRecipes() {
        let shouldEnable = !extendedRecipesEnabled
        if apiSourceEnabled != shouldEnable {
            apiSourceEnabled = userDataService.toggleSource(.online)
        }
        if aiSourceEnabled != shouldEnable {
            aiSourceEnabled = userDataService.toggleSource(.ai)
        }
    }

    func canAccessSource(_ source: RecipeSourceType) -> Bool {
        switch source {
        case .offline:
            return true
        case .online:
            return subscriptionService.canAccessFeature(.onlineRecipes)
        case .ai:
            return subscriptionService.canAccessFeature(.aiRecipes)
        }
    }

    func updateThemePreference(_ themePreference: ThemePreference) {
        guard self.themePreference != themePreference else { return }
        self.themePreference = themePreference
        userDataService.setThemePreference(themePreference)
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
        defer { isLoading = false }

        do {
            // Load database stats
            recipeCount = try await getRecipeCount()
            favoriteCount = try await getFavoriteCount()
            recentRecipeCount = try await getRecentRecipeCount()
        } catch {
            print("❌ Failed to load settings: \(error)")
        }
    }

    func clearRecentData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await userDataService.clearRecentData()
            // Reload stats
            await loadSettings()
        } catch {
            print("❌ Failed to clear recent data: \(error)")
        }
    }

    func clearFavorites() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await userDataService.clearFavorites()
            // Reload stats
            await loadSettings()
        } catch {
            print("❌ Failed to clear favorites: \(error)")
        }
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
