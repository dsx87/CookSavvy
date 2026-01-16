//
//  SettingsViewModel.swift
//  CookSavvy
//
//  Created by Claude on 16/01/2026.
//

import SwiftUI

/// Subscription plan types
enum SubscriptionPlan: String {
    case free = "Free"
    case api = "API" // Future
    case ai = "AI" // Future

    var displayName: String {
        rawValue
    }

    var description: String {
        switch self {
        case .free:
            return "Local database recipes"
        case .api:
            return "Curated recipe API + AI detection"
        case .ai:
            return "AI-generated recipes + AI detection"
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentPlan: SubscriptionPlan = .free
    @Published var recipeCount: Int = 0
    @Published var favoriteCount: Int = 0
    @Published var recentRecipeCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var showClearRecentAlert: Bool = false
    @Published var showClearFavoritesAlert: Bool = false

    // MARK: - Properties

    let appVersion: String
    let buildNumber: String

    private let userDataService: UserDataService
    private let dbInterface: DBInterfaceProtocol

    // MARK: - Initialization

    init(userDataService: UserDataService, dbInterface: DBInterfaceProtocol) {
        self.userDataService = userDataService
        self.dbInterface = dbInterface

        // Get app version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.appVersion = version
        } else {
            self.appVersion = "Unknown"
        }

        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.buildNumber = build
        } else {
            self.buildNumber = "Unknown"
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
        let recent = try await userDataService.getRecentRecipes(limit: 1000)
        return recent.count
    }
}
