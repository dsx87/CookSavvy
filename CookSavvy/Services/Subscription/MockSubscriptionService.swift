//
//  MockSubscriptionService.swift
//  CookSavvy
//

import Foundation
import Combine

@MainActor
final class MockSubscriptionService: SubscriptionServiceProtocol {
    
    @Published private(set) var currentPlan: SubscriptionPlan
    
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> {
        $currentPlan.eraseToAnyPublisher()
    }
    
    init(initialPlan: SubscriptionPlan = .free) {
        self.currentPlan = initialPlan
    }
    
    func canAccessFeature(_ feature: PaidFeature) -> Bool {
        feature.requiredPlans.contains(currentPlan)
    }
    
    func refreshSubscriptionStatus() async {
        // No-op for mock
    }
    
    func purchase(_ plan: SubscriptionPlan) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        currentPlan = plan
    }
    
    func restorePurchases() async throws {
        // No-op for mock
    }

    func price(for plan: SubscriptionPlan) async -> String? {
        switch plan {
        case .free:
            return nil
        case .premium:
            return "$4.99"
        }
    }
    
    // MARK: - Test Helpers
    
    func setPlan(_ plan: SubscriptionPlan) {
        currentPlan = plan
    }
}
