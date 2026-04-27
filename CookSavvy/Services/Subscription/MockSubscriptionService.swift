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

    /// Override these values in tests that need locale-specific price displays.
    var priceByOption: [PremiumSubscriptionOption: String] = [
        .monthly: "$4.99",
        .yearly: "$39.99"
    ]

    /// Override these values in tests that need custom subscription math.
    var priceAmountByOption: [PremiumSubscriptionOption: Decimal] = [
        .monthly: Decimal(string: "4.99") ?? .zero,
        .yearly: Decimal(string: "39.99") ?? .zero
    ]

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
    
    /// Simulates a premium option purchase with a 0.5 s delay, then grants its entitlement plan.
    func purchase(_ option: PremiumSubscriptionOption) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        _currentPlan.send(option.associatedPlan)
    }

    /// Simulates a plan purchase through the default purchasable option for compatibility.
    func purchase(_ plan: SubscriptionPlan) async throws {
        guard let option = PremiumSubscriptionOption.defaultOption(for: plan) else {
            throw SubscriptionError.productNotFound
        }

        try await purchase(option)
    }
    
    /// No-op for mock — restoring purchases has no effect.
    func restorePurchases() async throws {
        // No-op for mock
    }

    /// Returns hard-coded display prices matching the live App Store configuration.
    func price(for option: PremiumSubscriptionOption) async -> String? {
        priceByOption[option]
    }

    /// Returns hard-coded numeric prices matching the live App Store configuration.
    func priceAmount(for option: PremiumSubscriptionOption) async -> Decimal? {
        priceAmountByOption[option]
    }

    /// Returns hard-coded display prices for a plan's default purchasable option.
    func price(for plan: SubscriptionPlan) async -> String? {
        guard let option = PremiumSubscriptionOption.defaultOption(for: plan) else {
            return nil
        }

        return await price(for: option)
    }
    
    // MARK: - Test Helpers
    
    /// Directly updates the simulated subscription plan, emitting the change immediately.
    /// - Parameter plan: The plan to switch to.
    func setPlan(_ plan: SubscriptionPlan) {
        _currentPlan.send(plan)
    }
}
