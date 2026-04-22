//
//  MockSubscriptionService.swift
//  CookSavvy
//

import Foundation
import Combine

/// Test double for `SubscriptionServiceProtocol`, used in DEBUG builds and UI tests.
///
/// Initialised with a plan (defaulting to `.free`) and supports synchronous plan mutation
/// via `setPlan(_:)` for in-process test flows. The `--premium-user` launch argument
/// triggers creation with `.premium` to test premium-gated UI paths.
final class MockSubscriptionService: SubscriptionServiceProtocol {

    /// Backing subject powering both `currentPlan` and `currentPlanPublisher`.
    private let _currentPlan: CurrentValueSubject<SubscriptionPlan, Never>

    /// The currently simulated subscription plan.
    var currentPlan: SubscriptionPlan { _currentPlan.value }

    /// Tracks how many times `refreshSubscriptionStatus()` has been called; useful in unit tests.
    private(set) var refreshCallCount = 0

    /// Emits plan changes reactively.
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> {
        _currentPlan.eraseToAnyPublisher()
    }

    /// Creates a mock service with the given initial plan.
    /// - Parameter initialPlan: The plan to start with. Defaults to `.free`.
    init(initialPlan: SubscriptionPlan = .free) {
        self._currentPlan = CurrentValueSubject(initialPlan)
    }
    
    /// Returns whether the simulated plan grants access to the given feature.
    func canAccessFeature(_ feature: PaidFeature) -> Bool {
        feature.requiredPlans.contains(currentPlan)
    }
    
    /// No-op aside from incrementing `refreshCallCount`.
    func refreshSubscriptionStatus() async {
        refreshCallCount += 1
    }
    
    /// Simulates a purchase with a 0.5 s delay, then updates the plan.
    func purchase(_ plan: SubscriptionPlan) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        _currentPlan.send(plan)
    }
    
    /// No-op for mock — restoring purchases has no effect.
    func restorePurchases() async throws {
        // No-op for mock
    }

    /// Returns hard-coded display prices matching the live App Store configuration.
    func price(for plan: SubscriptionPlan) async -> String? {
        switch plan {
        case .free:
            return nil
        case .premium:
            return "$4.99"
        }
    }
    
    // MARK: - Test Helpers
    
    /// Directly updates the simulated subscription plan, emitting the change immediately.
    /// - Parameter plan: The plan to switch to.
    func setPlan(_ plan: SubscriptionPlan) {
        _currentPlan.send(plan)
    }
}
