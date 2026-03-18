//
//  UpgradeViewModel.swift
//  CookSavvy
//

import Foundation
import Combine

@MainActor
final class UpgradeViewModel: ObservableObject {
    
    @Published private(set) var currentPlan: SubscriptionPlan = .free
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var purchaseError: String?
    @Published var showErrorAlert: Bool = false
    @Published private(set) var priceByPlan: [SubscriptionPlan: String] = [:]
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let onDismiss: () -> Void
    private var cancellables = Set<AnyCancellable>()
    
    let availablePlans: [SubscriptionPlan] = [.premium]
    
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
    
    deinit {
        
    }
    
    func trackScreenViewed() {
        analyticsService.track(.upgradeScreenViewed)
    }

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
    
    func loadPrices() async {
        var prices: [SubscriptionPlan: String] = [:]

        for plan in availablePlans {
            if let price = await subscriptionService.price(for: plan) {
                prices[plan] = price
            }
        }

        priceByPlan = prices
    }

    func dismiss() {
        analyticsService.track(.upgradeDismissed)
        onDismiss()
    }

    func priceText(for plan: SubscriptionPlan) -> String {
        guard plan != .free else {
            return "Free"
        }

        if let price = priceByPlan[plan] {
            return "\(price)/month"
        }

        return "Loading price..."
    }
    
    func featureDescription(for plan: SubscriptionPlan) -> [String] {
        switch plan {
        case .free:
            return ["Basic recipe discovery"]
        case .premium:
            return [
                "Unlimited recipe sources",
                "Camera ingredient scanning",
                "AI-powered features",
                "Priority suggestions"
            ]
        }
    }
}
