//
//  SubscriptionPlan.swift
//  CookSavvy
//

import Foundation

/// The user's subscription tier, determining which recipe sources and features are accessible.
///
/// Plans are ordered by value (`free < premium`), enabling comparisons with `<`.
nonisolated enum SubscriptionPlan: String, CaseIterable, Codable, Comparable {
    /// The default, unpaid tier with local recipe discovery only.
    case free = "Free"
    /// The paid CookSavvy+ tier with unlimited recipes, camera scanning, and AI features.
    case premium = "Premium"

    /// Localised display name shown in the Settings and Upgrade screens.
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "CookSavvy+"
        }
    }

    /// Short description of what the plan includes.
    var description: String {
        switch self {
        case .free: return "Basic recipe discovery"
        case .premium: return "Unlimited recipes, camera scanning & smart features"
        }
    }

    /// Numeric tier value used to implement `Comparable` ordering.
    private var tier: Int {
        switch self {
        case .free: return 0
        case .premium: return 1
        }
    }

    /// Orders plans by tier value so that `free < premium`.
    static func < (lhs: SubscriptionPlan, rhs: SubscriptionPlan) -> Bool {
        lhs.tier < rhs.tier
    }
}

/// Purchasable CookSavvy+ subscription products.
///
/// `SubscriptionPlan` models entitlement state (`free` or `premium`), while this type
/// models the concrete StoreKit products a customer can buy to unlock the premium tier.
nonisolated enum PremiumSubscriptionOption: String, CaseIterable, Codable, Hashable, Identifiable {
    /// Annual billing for CookSavvy+, promoted as the best-value option.
    case yearly
    /// Monthly billing for CookSavvy+.
    case monthly

    /// Stable identity for SwiftUI lists and tests.
    var id: String { rawValue }

    /// StoreKit product identifier configured in App Store Connect and `Configuration.storekit`.
    var productIdentifier: String {
        switch self {
        case .monthly:
            return "com.cooksavvy.subscription.premium"
        case .yearly:
            return "com.cooksavvy.subscription.premium.yearly"
        }
    }

    /// The entitlement tier unlocked by this purchasable product.
    var associatedPlan: SubscriptionPlan {
        .premium
    }

    /// User-facing billing cadence label for this option.
    var billingPeriodLabel: String {
        switch self {
        case .monthly:
            return Strings.Upgrade.monthlyOptionTitle
        case .yearly:
            return Strings.Upgrade.annualOptionTitle
        }
    }

    /// Whether this option should be visually promoted on the paywall.
    var isPromoted: Bool {
        self == .yearly
    }

    /// Looks up an option by StoreKit product identifier.
    /// - Parameter productIdentifier: The StoreKit product ID from a transaction or product load.
    /// - Returns: The matching subscription option, or `nil` if the ID is unknown.
    static func option(for productIdentifier: String) -> PremiumSubscriptionOption? {
        allCases.first { $0.productIdentifier == productIdentifier }
    }

    /// The default product used by legacy plan-based purchase and price APIs.
    /// - Parameter plan: The entitlement plan being purchased.
    /// - Returns: The monthly premium option for `.premium`, or `nil` for `.free`.
    static func defaultOption(for plan: SubscriptionPlan) -> PremiumSubscriptionOption? {
        switch plan {
        case .free:
            return nil
        case .premium:
            return .monthly
        }
    }
}

/// Snapshot of the user's current subscription entitlement and trial state.
///
/// The app still uses `SubscriptionPlan` for premium gating, but T-007 needs extra
/// context so the UI can distinguish a paid premium customer from someone who is
/// actively using the monthly introductory free trial.
nonisolated struct SubscriptionStatus: Equatable, Codable {
    /// The effective entitlement tier used for feature access checks.
    let plan: SubscriptionPlan
    /// The currently active product, when StoreKit has enough information to identify it.
    let activeOption: PremiumSubscriptionOption?
    /// Whether the user can still start the monthly introductory offer.
    let isEligibleForMonthlyTrial: Bool
    /// Whether the current premium access is coming from a free trial.
    let isOnFreeTrial: Bool
    /// The current trial's end date when StoreKit exposes it.
    let trialExpirationDate: Date?

    static func free(isEligibleForMonthlyTrial: Bool = false) -> SubscriptionStatus {
        SubscriptionStatus(
            plan: .free,
            activeOption: nil,
            isEligibleForMonthlyTrial: isEligibleForMonthlyTrial,
            isOnFreeTrial: false,
            trialExpirationDate: nil
        )
    }

    static func premium(
        option: PremiumSubscriptionOption,
        isEligibleForMonthlyTrial: Bool = false,
        isOnFreeTrial: Bool = false,
        trialExpirationDate: Date? = nil
    ) -> SubscriptionStatus {
        SubscriptionStatus(
            plan: .premium,
            activeOption: option,
            isEligibleForMonthlyTrial: isEligibleForMonthlyTrial,
            isOnFreeTrial: isOnFreeTrial,
            trialExpirationDate: trialExpirationDate
        )
    }

    /// Localized medium-style date used in Upgrade and Settings trial messaging.
    var formattedTrialEndDate: String? {
        guard let trialExpirationDate else {
            return nil
        }

        return DateFormatter.localizedString(
            from: trialExpirationDate,
            dateStyle: .medium,
            timeStyle: .none
        )
    }
}

/// Premium-gated features that require an active CookSavvy+ subscription.
nonisolated enum PaidFeature {
    /// AI-powered camera scanning for ingredient detection.
    case cameraIngredientDetection
    /// Access to the Supabase-backed online recipe catalogue.
    case onlineRecipes
    /// Access to AI-generated recipes.
    case aiRecipes
    /// The shopping list for missing ingredients.
    case shoppingList
    /// Premium monthly My Kitchen insights, including approximate savings.
    case monthlyCookingInsights

    /// The set of subscription plans that unlock this feature.
    var requiredPlans: Set<SubscriptionPlan> {
        return [.premium]
    }

    /// Display name shown on the Upgrade screen for this feature.
    var displayName: String {
        switch self {
        case .cameraIngredientDetection: return "Camera Scanning"
        case .onlineRecipes: return "Extended Recipes"
        case .aiRecipes: return "AI Recipes"
        case .shoppingList: return "Shopping List"
        case .monthlyCookingInsights: return "Monthly Cooking Insights"
        }
    }
}
