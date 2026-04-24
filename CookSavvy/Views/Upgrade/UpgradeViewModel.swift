//
//  UpgradeViewModel.swift
//  CookSavvy
//

import Foundation
import Combine

/// ViewModel backing the Upgrade paywall screen.
///
/// Loads live pricing from StoreKit and manages the purchase flow for the CookSavvy+ plan.
/// Calls `onDismiss` on successful purchase or explicit dismissal.
@MainActor
final class UpgradeViewModel: ObservableObject {

    /// The user's current subscription plan; updated live from the service.
    @Published private(set) var currentPlan: SubscriptionPlan = .free
    /// `true` while a purchase request is in flight.
    @Published private(set) var isLoading: Bool = false
    /// The error message to display when a purchase fails (non-`nil` triggers `showErrorAlert`).
    @Published private(set) var purchaseError: String?
    /// Controls the purchase error alert.
    @Published var showErrorAlert: Bool = false
    /// Cached localised price strings keyed by plan.
    @Published private(set) var priceByPlan: [SubscriptionPlan: String] = [:]
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let onDismiss: () -> Void
    private var cancellables = Set<AnyCancellable>()
    
    /// The plans shown on the paywall. Currently only `.premium` is offered.
    let availablePlans: [SubscriptionPlan] = [.premium]
    
    /// Creates the paywall view model and subscribes to live plan updates.
    init(
        subscriptionService: SubscriptionServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.subscriptionService = subscriptionService
        self.analyticsService = analyticsService
        self.onDismiss = onDismiss
        self.currentPlan = subscriptionService.currentPlan
        
        subscriptionService.currentPlanPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] plan in
                self?.currentPlan = plan
            }
            .store(in: &cancellables)
    }
    
    /// Explicit no-op deinitializer (kept for lifecycle parity with earlier implementations).
    deinit {
        
    }
    
    /// Tracks an upgrade screen view impression for analytics.
    func trackScreenViewed() {
        analyticsService.track(.upgradeScreenViewed)
    }

    /// Initiates a StoreKit purchase for the given plan.
    ///
    /// User-cancellation is silently ignored. All other errors set `purchaseError` and show the alert.
    /// On success, tracks the purchase event and calls `onDismiss`.
    func purchase(_ plan: SubscriptionPlan) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        
        do {
            try await subscriptionService.purchase(plan)
            analyticsService.track(.upgradePurchased)
            onDismiss()
        } catch let error as SubscriptionError {
            if case .userCancelled = error {
                return
            }
            purchaseError = error.localizedDescription
            showErrorAlert = true
        } catch {
            purchaseError = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    /// Fetches localised price strings for all `availablePlans` and populates `priceByPlan`.
    func loadPrices() async {
        var prices: [SubscriptionPlan: String] = [:]

        for plan in availablePlans {
            if let price = await subscriptionService.price(for: plan) {
                prices[plan] = price
            }
        }

        priceByPlan = prices
    }

    /// Tracks a dismiss event and calls `onDismiss`.
    func dismiss() {
        analyticsService.track(.upgradeDismissed)
        onDismiss()
    }

    /// Returns the localised price string for a plan (e.g. "$4.99/month"), or a loading placeholder.
    func priceText(for plan: SubscriptionPlan) -> String {
        guard plan != .free else {
            return Strings.Upgrade.freePrice
        }

        if let price = priceByPlan[plan] {
            return String(format: Strings.Upgrade.monthlyPriceFormat, price)
        }

        return Strings.Upgrade.loadingPrice
    }
    
    /// Returns the feature bullet points shown on the paywall card for the given plan.
    func featureDescription(for plan: SubscriptionPlan) -> [String] {
        switch plan {
        case .free:
            return [Strings.Upgrade.freeFeatureBasicDiscovery]
        case .premium:
            return [
                Strings.Upgrade.premiumFeatureScanFridge,
                Strings.Upgrade.premiumFeatureNeverMissIngredient,
                Strings.Upgrade.premiumFeatureShoppingLists,
                Strings.Upgrade.premiumFeatureSmarterSuggestions
            ]
        }
    }
}
