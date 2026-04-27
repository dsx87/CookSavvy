//
//  SubscriptionServiceProtocol.swift
//  CookSavvy
//

import Foundation
import Combine

/// Interface for subscription management, abstracting StoreKit 2 for testability.
///
/// Provides the current plan, reactive plan updates, feature gating, and
/// purchase/restore operations. Premium entitlement can be purchased through
/// monthly or annual `PremiumSubscriptionOption` products.
protocol SubscriptionServiceProtocol: AnyObject {
    /// The user's currently active subscription plan.
    var currentPlan: SubscriptionPlan { get }

    /// A publisher that emits the subscription plan whenever it changes.
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> { get }

    /// Returns whether the current plan grants access to the specified premium feature.
    /// - Parameter feature: The feature to check.
    /// - Returns: `true` if the current plan satisfies the feature's requirements.
    func canAccessFeature(_ feature: PaidFeature) -> Bool

    /// Fetches the latest entitlements from StoreKit and updates `currentPlan`.
    func refreshSubscriptionStatus() async

    /// Initiates a purchase for the given premium subscription option via StoreKit.
    /// - Parameter option: The purchasable product to buy.
    /// - Throws: `SubscriptionError` if the product is not found, purchase fails, or the user cancels.
    func purchase(_ option: PremiumSubscriptionOption) async throws

    /// Initiates a purchase for the given plan via StoreKit.
    ///
    /// This compatibility API purchases the default product for the entitlement tier.
    /// - Parameter plan: The plan to purchase.
    /// - Throws: `SubscriptionError` if the product is not found, purchase fails, or the user cancels.
    func purchase(_ plan: SubscriptionPlan) async throws

    /// Syncs with the App Store and refreshes entitlements to restore prior purchases.
    /// - Throws: `SubscriptionError.noPurchasesToRestore` if no active purchases are found.
    func restorePurchases() async throws

    /// Returns the localized display price for a premium subscription option, or `nil` if unavailable.
    /// - Parameter option: The purchasable product whose price to fetch.
    /// - Returns: A formatted price string (e.g. `"$4.99"`).
    func price(for option: PremiumSubscriptionOption) async -> String?

    /// Returns the numeric price for a premium subscription option, or `nil` if unavailable.
    /// - Parameter option: The purchasable product whose price to fetch.
    /// - Returns: A decimal amount matching the StoreKit product price.
    func priceAmount(for option: PremiumSubscriptionOption) async -> Decimal?

    /// Returns the localized display price for a plan, or `nil` if unavailable.
    ///
    /// This compatibility API returns the default product price for the entitlement tier.
    /// - Parameter plan: The plan whose price to fetch.
    /// - Returns: A formatted price string (e.g. `"$4.99"`) or `nil` for the free plan.
    func price(for plan: SubscriptionPlan) async -> String?
}

/// Errors that can occur during subscription operations.
enum SubscriptionError: Error, LocalizedError {
    /// The StoreKit product for the requested plan could not be loaded.
    case productNotFound
    /// The purchase call itself threw an error.
    case purchaseFailed(Error)
    /// StoreKit returned a transaction that failed JWS signature verification.
    case verificationFailed
    /// The user dismissed the payment sheet without completing the purchase.
    case userCancelled
    /// `AppStore.sync()` completed but no active subscriptions were found.
    case noPurchasesToRestore
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .verificationFailed:
            return "Could not verify purchase"
        case .userCancelled:
            return "Purchase was cancelled"
        case .noPurchasesToRestore:
            return "No purchases to restore"
        }
    }
}
