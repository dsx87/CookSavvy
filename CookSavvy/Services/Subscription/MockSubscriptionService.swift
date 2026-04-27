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

    /// Backing subject powering both plan-level and trial-aware subscription publishers.
    private let _currentSubscriptionStatus: CurrentValueSubject<SubscriptionStatus, Never>
    private let analyticsService: AnalyticsServiceProtocol?

    /// The currently simulated subscription plan.
    var currentPlan: SubscriptionPlan { currentSubscriptionStatus.plan }

    /// The currently simulated subscription snapshot.
    var currentSubscriptionStatus: SubscriptionStatus { _currentSubscriptionStatus.value }

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

    /// Emits full subscription status changes reactively.
    var currentSubscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> {
        _currentSubscriptionStatus.eraseToAnyPublisher()
    }

    /// Emits plan changes reactively.
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> {
        _currentSubscriptionStatus
            .map(\.plan)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Creates a mock service with the given initial plan.
    /// - Parameter initialPlan: The plan to start with. Defaults to `.free`.
    init(
        initialPlan: SubscriptionPlan = .free,
        analyticsService: AnalyticsServiceProtocol? = nil
    ) {
        self.analyticsService = analyticsService
        let initialStatus: SubscriptionStatus
        switch initialPlan {
        case .free:
            initialStatus = .free(isEligibleForMonthlyTrial: true)
        case .premium:
            initialStatus = .premium(option: .monthly)
        }
        self._currentSubscriptionStatus = CurrentValueSubject(initialStatus)
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
        let trialEndDate = option == .monthly && currentSubscriptionStatus.isEligibleForMonthlyTrial
            ? Calendar.current.date(byAdding: .day, value: 7, to: Date())
            : nil

        publish(
            .premium(
                option: option,
                isEligibleForMonthlyTrial: false,
                isOnFreeTrial: trialEndDate != nil,
                trialExpirationDate: trialEndDate
            )
        )
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
        switch plan {
        case .free:
            publish(.free(isEligibleForMonthlyTrial: currentSubscriptionStatus.isEligibleForMonthlyTrial))
        case .premium:
            publish(.premium(option: currentSubscriptionStatus.activeOption ?? .monthly))
        }
    }

    /// Directly updates the full simulated subscription status for trial-aware tests.
    /// - Parameter status: The new subscription snapshot to publish.
    func setSubscriptionStatus(_ status: SubscriptionStatus) {
        publish(status)
    }

    private func publish(_ status: SubscriptionStatus) {
        let previousStatus = currentSubscriptionStatus
        _currentSubscriptionStatus.send(status)

        guard let analyticsService else {
            return
        }

        for analyticsEvent in SubscriptionStatusTransitionAnalytics.trialLifecycleEvents(
            from: previousStatus,
            to: status
        ) {
            analyticsService.track(analyticsEvent.event, properties: analyticsEvent.properties)
        }
    }
}
