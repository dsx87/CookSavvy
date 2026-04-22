//
//  MockSubscriptionService.swift
//  CookSavvy
//

import Foundation
import Combine

final class MockSubscriptionService: SubscriptionServiceProtocol {

    private let _currentPlan: CurrentValueSubject<SubscriptionPlan, Never>

    var currentPlan: SubscriptionPlan { _currentPlan.value }
    private(set) var refreshCallCount = 0

    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> {
        _currentPlan.eraseToAnyPublisher()
    }

    init(initialPlan: SubscriptionPlan = .free) {
        self._currentPlan = CurrentValueSubject(initialPlan)
    }
    
    func canAccessFeature(_ feature: PaidFeature) -> Bool {
        feature.requiredPlans.contains(currentPlan)
    }
    
    func refreshSubscriptionStatus() async {
        refreshCallCount += 1
    }
    
    func purchase(_ plan: SubscriptionPlan) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        _currentPlan.send(plan)
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
        _currentPlan.send(plan)
    }
}
