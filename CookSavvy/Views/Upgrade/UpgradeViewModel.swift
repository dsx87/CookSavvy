//
//  UpgradeViewModel.swift
//  CookSavvy
//

import Foundation
import Observation
import UIKit

/// ViewModel backing the Upgrade paywall screen.
///
/// Loads live pricing from StoreKit and manages the purchase flow for CookSavvy+ options.
/// Calls `onDismiss` on successful purchase or explicit dismissal.
@Observable final class UpgradeViewModel {

    /// The user's current subscription plan; updated live from the service.
    private(set) var currentPlan: SubscriptionPlan = .free
    /// Trial-aware subscription snapshot used by the paywall UI.
    private(set) var currentSubscriptionStatus: SubscriptionStatus = .free()
    /// `true` while a purchase request is in flight.
    private(set) var isLoading: Bool = false
    /// The error message to display when a purchase fails (non-`nil` triggers `showErrorAlert`).
    private(set) var purchaseError: String?
    /// Controls the purchase error alert.
    var showErrorAlert: Bool = false
    /// `true` while a restore-purchases request is in flight.
    private(set) var isRestoringPurchases: Bool = false
    /// The error message to display when a restore fails (non-`nil` drives the restore error alert).
    var restoreError: String?
    /// Cached localised price strings keyed by purchasable option.
    private(set) var priceByOption: [PremiumSubscriptionOption: String] = [:]
    /// Cached numeric prices keyed by purchasable option, used for annual savings math.
    private(set) var priceAmountByOption: [PremiumSubscriptionOption: Decimal] = [:]
    
    private let subscriptionService: SubscriptionServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let onDismiss: () -> Void
    /// Long-lived task consuming the subscription-status stream; cancelled on deinit.
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    
    /// The entitlement plans shown on the paywall. Kept for compatibility with existing tests.
    let availablePlans: [SubscriptionPlan] = [.premium]

    /// The purchasable products shown on the paywall, ordered with annual first for promotion.
    let availableOptions: [PremiumSubscriptionOption] = [.yearly, .monthly]

    var headerSubtitle: String {
        if currentSubscriptionStatus.isOnFreeTrial {
            return Strings.Upgrade.trialActiveSubtitle
        }

        if currentSubscriptionStatus.isEligibleForMonthlyTrial {
            return Strings.Upgrade.trialEligibleSubtitle
        }

        return Strings.Upgrade.unlockSubtitle
    }
    
    /// Creates the paywall view model and subscribes to live plan updates.
    init(
        subscriptionService: SubscriptionServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        onDismiss: @escaping () -> Void
    ) {
        self.subscriptionService = subscriptionService
        self.analyticsService = analyticsService
        self.onDismiss = onDismiss
        self.currentSubscriptionStatus = subscriptionService.currentSubscriptionStatus
        self.currentPlan = currentSubscriptionStatus.plan
        
        let statusUpdates = subscriptionService.currentSubscriptionStatusUpdates
        observationTasks.append(Task { [weak self] in
            for await status in statusUpdates {
                guard let self else { return }
                self.currentSubscriptionStatus = status
                self.currentPlan = status.plan
            }
        })
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
    }
    
    /// Tracks an upgrade screen view impression for analytics.
    func trackScreenViewed() {
        analyticsService.track(.upgradeScreenViewed)
    }

    /// Initiates a StoreKit purchase for the given subscription option.
    ///
    /// User-cancellation is silently ignored. All other errors set `purchaseError` and show the alert.
    /// On success, tracks the purchase event and calls `onDismiss`.
    func purchase(_ option: PremiumSubscriptionOption) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        
        do {
            try await subscriptionService.purchase(option)
            // Attach the StoreKit product id so the upgrade-conversion funnel can split monthly vs.
            // yearly remotely, mirroring the `product_id` already carried by the trial events.
            analyticsService.track(.upgradePurchased, properties: ["product_id": option.productIdentifier])
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

    /// Purchases the default option for an entitlement plan, preserving older call sites.
    func purchase(_ plan: SubscriptionPlan) async {
        guard let option = PremiumSubscriptionOption.defaultOption(for: plan) else {
            purchaseError = SubscriptionError.productNotFound.localizedDescription
            showErrorAlert = true
            return
        }

        await purchase(option)
    }
    
    /// Fetches localised price strings and numeric amounts for all `availableOptions`.
    func loadPrices() async {
        var prices: [PremiumSubscriptionOption: String] = [:]
        var amounts: [PremiumSubscriptionOption: Decimal] = [:]

        for option in availableOptions {
            if let price = await subscriptionService.price(for: option) {
                prices[option] = price
            }

            if let amount = await subscriptionService.priceAmount(for: option) {
                amounts[option] = amount
            }
        }

        priceByOption = prices
        priceAmountByOption = amounts
    }

    /// Restores previously purchased subscriptions via StoreKit.
    ///
    /// Required on the paywall for App Store compliance (Guideline 3.1.1). Mirrors the Settings
    /// restore flow; failures populate `restoreError` to drive an alert.
    func restorePurchases() async {
        isRestoringPurchases = true
        restoreError = nil
        defer { isRestoringPurchases = false }

        do {
            try await subscriptionService.restorePurchases()
        } catch {
            restoreError = error.localizedDescription
        }
    }

    /// Opens the hosted Terms of Use page in the system browser.
    func openTermsOfUse() {
        if let url = LegalLinks.termsOfUse {
            UIApplication.shared.open(url)
        }
    }

    /// Opens the hosted Privacy Policy page in the system browser.
    func openPrivacyPolicy() {
        if let url = LegalLinks.privacyPolicy {
            UIApplication.shared.open(url)
        }
    }

    /// Tracks a dismiss event and calls `onDismiss`.
    func dismiss() {
        analyticsService.track(.upgradeDismissed)
        onDismiss()
    }

    /// Returns the localised price string for a subscription option (e.g. "$4.99/month").
    func priceText(for option: PremiumSubscriptionOption) -> String {
        guard let price = priceByOption[option] else {
            return Strings.Upgrade.loadingPrice
        }

        switch option {
        case .monthly:
            if isCurrentOption(option),
               currentSubscriptionStatus.isOnFreeTrial,
               let trialEndDate = currentSubscriptionStatus.formattedTrialEndDate {
                return String(format: Strings.Upgrade.monthlyTrialActivePriceFormat, trialEndDate, price)
            }

            if currentSubscriptionStatus.isEligibleForMonthlyTrial {
                return String(format: Strings.Upgrade.monthlyTrialPriceFormat, price)
            }

            return String(format: Strings.Upgrade.monthlyPriceFormat, price)
        case .yearly:
            return String(format: Strings.Upgrade.annualPriceFormat, price)
        }
    }

    /// Returns the localised price string for a plan's default option, or a loading placeholder.
    func priceText(for plan: SubscriptionPlan) -> String {
        guard plan != .free else {
            return Strings.Upgrade.freePrice
        }

        guard let option = PremiumSubscriptionOption.defaultOption(for: plan) else {
            return Strings.Upgrade.loadingPrice
        }

        return priceText(for: option)
    }

    /// Returns annual savings copy when both monthly and annual numeric prices are available.
    func savingsText(for option: PremiumSubscriptionOption) -> String? {
        guard option == .yearly,
              let savings = annualSavingsAmount(),
              isPositive(savings) else {
            return nil
        }

        return String(format: Strings.Upgrade.annualSavingsFormat, formatSavingsAmount(savings))
    }

    /// Returns the display title for a purchasable option.
    func optionTitle(for option: PremiumSubscriptionOption) -> String {
        option.billingPeriodLabel
    }

    /// Returns the pill badge shown next to a plan heading.
    func optionBadgeText(for option: PremiumSubscriptionOption) -> String? {
        if option == .monthly && currentSubscriptionStatus.isEligibleForMonthlyTrial && !isCurrentOption(option) {
            return Strings.Upgrade.freeTrialBadge
        }

        if option.isPromoted {
            return Strings.Upgrade.bestValue
        }

        return nil
    }

    /// Returns the CTA title shown on a plan card.
    func purchaseButtonText(for option: PremiumSubscriptionOption) -> String {
        option == .monthly && currentSubscriptionStatus.isEligibleForMonthlyTrial
            ? Strings.Upgrade.tryFreeForSevenDays
            : Strings.Upgrade.subscribe
    }

    /// Returns the current-state badge for the active product.
    func currentBadgeText(for option: PremiumSubscriptionOption) -> String? {
        guard isCurrentOption(option) else {
            return nil
        }

        return currentSubscriptionStatus.isOnFreeTrial
            ? Strings.Upgrade.trialActive
            : Strings.Upgrade.current
    }

    /// Returns whether this option is the currently active StoreKit product.
    func isCurrentOption(_ option: PremiumSubscriptionOption) -> Bool {
        guard currentPlan == .premium else {
            return false
        }

        return currentSubscriptionStatus.activeOption == option
    }

    /// Calculates yearly savings against paying the monthly price for 12 months.
    func annualSavingsAmount() -> Decimal? {
        guard let monthly = priceAmountByOption[.monthly],
              let yearly = priceAmountByOption[.yearly] else {
            return nil
        }

        return monthly * Decimal(12) - yearly
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

    /// Formats a computed savings amount by reusing the loaded monthly price's currency wrapper.
    ///
    /// StoreKit supplies localized display strings and numeric amounts separately. Replacing the
    /// numeric part of the loaded price keeps the savings copy aligned with the visible price
    /// while avoiding a hard-coded currency symbol.
    private func formatSavingsAmount(_ amount: Decimal) -> String {
        guard let monthlyPrice = priceByOption[.monthly],
              let numberRange = monthlyPrice.rangeOfPriceNumber else {
            return Strings.Upgrade.annualSavingsFallbackAmount
        }

        guard let amountText = PriceNumberFormatter(localizedNumber: String(monthlyPrice[numberRange]))
            .string(from: amount) else {
            return Strings.Upgrade.annualSavingsFallbackAmount
        }

        return monthlyPrice.replacingCharacters(in: numberRange, with: amountText)
    }

    /// Compares decimals through `NSDecimalNumber` to avoid floating-point conversion.
    private func isPositive(_ amount: Decimal) -> Bool {
        NSDecimalNumber(decimal: amount).compare(NSDecimalNumber(decimal: 0)) == .orderedDescending
    }
}

fileprivate extension String {
    /// Finds the first numeric span inside a localized price string.
    ///
    /// The span includes digits and common decimal/grouping separators so values such as
    /// "$4.99" and "4,99 €" can preserve their currency prefix/suffix when replaced.
    var rangeOfPriceNumber: Range<String.Index>? {
        guard let start = firstIndex(where: { $0.isNumber }) else {
            return nil
        }

        var end = index(after: start)
        while end < endIndex {
            let character = self[end]
            guard character.isNumber || character == "." || character == "," else {
                break
            }
            end = index(after: end)
        }

        return start..<end
    }

    var detectedDecimalSeparator: Character? {
        let trailingDigits = trailingDigitCount
        guard (1...3).contains(trailingDigits), trailingDigits < count else {
            return nil
        }

        let separatorIndex = index(endIndex, offsetBy: -(trailingDigits + 1))
        let separator = self[separatorIndex]
        return separator.isNumber ? nil : separator
    }

    var trailingDigitCount: Int {
        reversed().prefix(while: { $0.isNumber }).count
    }
}

private struct PriceNumberFormatter {
    private let formatter = NumberFormatter()

    init(localizedNumber: String) {
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        if let decimalSeparator = localizedNumber.detectedDecimalSeparator {
            // Reuse the separator already visible in the StoreKit price so savings copy stays
            // consistent with the localized monthly price.
            formatter.decimalSeparator = String(decimalSeparator)
            let fractionDigits = localizedNumber.trailingDigitCount
            formatter.minimumFractionDigits = fractionDigits
            formatter.maximumFractionDigits = fractionDigits
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
    }

    func string(from amount: Decimal) -> String? {
        formatter.string(from: NSDecimalNumber(decimal: amount))
    }
}
