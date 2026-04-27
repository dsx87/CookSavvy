//
//  StoreKitSubscriptionService.swift
//  CookSavvy
//

import Foundation
import StoreKit
import Combine

/// Production StoreKit 2 implementation of `SubscriptionServiceProtocol`.
///
/// On init, this service:
/// 1. Immediately surfaces any cached plan from UserDefaults so the UI is never blank.
/// 2. Starts a detached background `Task` (via `listenForTransactions`) that observes
///    `Transaction.updates` — an async sequence that delivers out-of-band events such as
///    family-sharing grants, billing-issue recovery, and subscription revocations. This
///    listener must stay alive for the app's lifetime to keep entitlements up to date
///    without requiring a manual refresh.
/// 3. Kicks off an initial `refreshSubscriptionStatus()` to sync with the App Store.
// TODO: Review this
final class StoreKitSubscriptionService: SubscriptionServiceProtocol {

    /// Backing subject for the reactive subscription-status publisher.
    private let _currentSubscriptionStatus = CurrentValueSubject<SubscriptionStatus, Never>(.free())

    /// Serialises concurrent refresh calls so only one refresh runs at a time.
    private let refreshCoordinator = SubscriptionRefreshCoordinator()

    /// The user's currently active subscription plan.
    var currentPlan: SubscriptionPlan { currentSubscriptionStatus.plan }

    /// The user's full subscription snapshot, including trial state.
    var currentSubscriptionStatus: SubscriptionStatus { _currentSubscriptionStatus.value }

    /// Emits the full subscription snapshot on every change.
    var currentSubscriptionStatusPublisher: AnyPublisher<SubscriptionStatus, Never> {
        _currentSubscriptionStatus.eraseToAnyPublisher()
    }

    /// Emits the plan on every change, backed by `_currentSubscriptionStatus`.
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> {
        _currentSubscriptionStatus
            .map(\.plan)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Loaded StoreKit products keyed by product identifier.
    private var products: [String: Product] = [:]

    /// Handle to the long-lived transaction-listener task; cancelled on deinit.
    private var transactionListener: Task<Void, Error>?
    
    /// UserDefaults keys for the persisted subscription snapshot and legacy plan cache.
    private let statusCacheKey = "cached_subscription_status"
    private let legacyPlanCacheKey = "cached_subscription_plan"
    private let analyticsService: AnalyticsServiceProtocol
    private let logger: any LoggerProtocol
    
    /// Initialises the service, loads the cached plan, and begins listening for StoreKit updates.
    /// - Parameter logger: A scoped logger for error reporting.
    init(
        logger: any LoggerProtocol,
        analyticsService: AnalyticsServiceProtocol
    ) {
        self.logger = logger
        self.analyticsService = analyticsService
        loadCachedSubscriptionStatus()
        transactionListener = listenForTransactions()
        Task { [weak self] in
            await self?.refreshSubscriptionStatus()
        }
    }
    
    /// Stops the long-lived StoreKit transaction listener task.
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Protocol Methods
    
    /// Returns whether the current plan grants access to the given feature.
    func canAccessFeature(_ feature: PaidFeature) -> Bool {
        feature.requiredPlans.contains(currentPlan)
    }
    
    /// Refreshes the subscription status, coalescing concurrent calls via `SubscriptionRefreshCoordinator`.
    func refreshSubscriptionStatus() async {
        await refreshCoordinator.run { [weak self] in
            await self?.performRefreshSubscriptionStatus()
        }
    }

    /// Performs the actual product load + entitlement check without coordination.
    private func performRefreshSubscriptionStatus() async {
        await loadProducts()
        await updateSubscriptionStatus()
    }
    
    /// Purchases a premium subscription option through StoreKit 2, finishing the resulting transaction on success.
    ///
    /// Pending transactions (e.g. Ask to Buy) are silently accepted; they will resolve
    /// via the `Transaction.updates` listener when approved.
    /// - Parameter option: The purchasable subscription option to purchase.
    /// - Throws: `SubscriptionError` for missing products, purchase failures, or user cancellation.
    func purchase(_ option: PremiumSubscriptionOption) async throws {
        let productId = option.productIdentifier
        if products[productId] == nil {
            await loadProducts()
        }

        guard let product = products[productId] else {
            throw SubscriptionError.productNotFound
        }
        
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw SubscriptionError.purchaseFailed(error)
        }
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            
        case .userCancelled:
            throw SubscriptionError.userCancelled
            
        case .pending:
            break
            
        @unknown default:
            break
        }
    }

    /// Purchases the default product for an entitlement plan, preserving older call sites.
    func purchase(_ plan: SubscriptionPlan) async throws {
        guard let option = PremiumSubscriptionOption.defaultOption(for: plan) else {
            throw SubscriptionError.productNotFound
        }

        try await purchase(option)
    }
    
    /// Syncs with the App Store via `AppStore.sync()` and refreshes entitlements.
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    /// Returns the localized display price for the given purchasable option.
    ///
    /// Triggers a product load if the product hasn't been fetched yet.
    func price(for option: PremiumSubscriptionOption) async -> String? {
        let productId = option.productIdentifier
        if products[productId] == nil {
            await loadProducts()
        }

        return products[productId]?.displayPrice
    }

    /// Returns the numeric StoreKit price for the given purchasable option.
    ///
    /// The upgrade view model uses this to compute annual savings while preserving
    /// StoreKit's localized display price for the headline price text.
    func priceAmount(for option: PremiumSubscriptionOption) async -> Decimal? {
        let productId = option.productIdentifier
        if products[productId] == nil {
            await loadProducts()
        }

        return products[productId]?.price
    }

    /// Returns the localized display price for a plan's default purchasable option.
    func price(for plan: SubscriptionPlan) async -> String? {
        guard let option = PremiumSubscriptionOption.defaultOption(for: plan) else {
            return nil
        }

        return await price(for: option)
    }
    
    // MARK: - Private Methods
    
    /// Fetches all subscription products from the App Store and caches them in `products`.
    private func loadProducts() async {
        let productIds = PremiumSubscriptionOption.allCases.map(\.productIdentifier)
        guard !productIds.isEmpty else { return }
        
        do {
            let storeProducts = try await Product.products(for: Set(productIds))
            for product in storeProducts {
                products[product.id] = product
            }
        } catch {
            logger.error("Failed to load products: \(error)")
        }
    }
    
    /// Resolves the live subscription snapshot from StoreKit entitlements and intro-offer eligibility.
    ///
    /// The returned status keeps plan-based feature gating intact while adding the extra
    /// trial metadata required by T-007 for Settings, the paywall, and lifecycle analytics.
    private func updateSubscriptionStatus() async {
        var resolvedStatus = SubscriptionStatus.free()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            guard let option = PremiumSubscriptionOption.option(for: transaction.productID) else {
                continue
            }

            let isOnFreeTrial = isMonthlyFreeTrial(transaction, option: option)
            let candidateStatus = SubscriptionStatus.premium(
                option: option,
                isOnFreeTrial: isOnFreeTrial,
                trialExpirationDate: isOnFreeTrial ? transaction.expirationDate : nil
            )
            resolvedStatus = preferredStatus(between: resolvedStatus, and: candidateStatus)
        }

        let monthlyTrialEligibility = await loadMonthlyTrialEligibility()
        let finalStatus = SubscriptionStatus(
            plan: resolvedStatus.plan,
            activeOption: resolvedStatus.activeOption,
            isEligibleForMonthlyTrial: monthlyTrialEligibility,
            isOnFreeTrial: resolvedStatus.isOnFreeTrial,
            trialExpirationDate: resolvedStatus.trialExpirationDate
        )

        publishSubscriptionStatus(finalStatus)
    }
    
    /// Starts a detached background task that continuously observes `Transaction.updates`.
    ///
    /// This async sequence emits out-of-band StoreKit events that do not arrive through a
    /// normal purchase call — e.g. family-sharing grants, subscription renewals, billing
    /// recovery, and revocations. Each verified transaction is finished immediately and
    /// triggers a full entitlement re-check. Using `Task.detached` avoids inheriting any
    /// actor context so the loop can't block the main actor.
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.updateSubscriptionStatus()
            }
        }
    }
    
    /// Unwraps a `VerificationResult`, throwing `SubscriptionError.verificationFailed` for unverified items.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let item):
            return item
        case .unverified:
            throw SubscriptionError.verificationFailed
        }
    }
    
    // MARK: - Local Caching
    
    /// Reads the persisted subscription snapshot and pre-populates the subject before refresh.
    private func loadCachedSubscriptionStatus() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: statusCacheKey),
           let status = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
            _currentSubscriptionStatus.send(status)
            return
        }

        if let rawValue = defaults.string(forKey: legacyPlanCacheKey),
           let plan = SubscriptionPlan(rawValue: rawValue) {
            switch plan {
            case .free:
                _currentSubscriptionStatus.send(.free())
            case .premium:
                _currentSubscriptionStatus.send(.premium(option: .monthly))
            }
        }
    }

    /// Persists the resolved subscription snapshot so it survives app restarts.
    private func cacheSubscriptionStatus(_ status: SubscriptionStatus) {
        let defaults = UserDefaults.standard
        defaults.set(status.plan.rawValue, forKey: legacyPlanCacheKey)

        if let data = try? JSONEncoder().encode(status) {
            defaults.set(data, forKey: statusCacheKey)
        }
    }

    private func publishSubscriptionStatus(_ status: SubscriptionStatus) {
        let previousStatus = currentSubscriptionStatus
        _currentSubscriptionStatus.send(status)
        cacheSubscriptionStatus(status)

        // TODO(T-002): Preserve these trial lifecycle events when AnalyticsService moves
        // from local logging to a remote SDK so the funnel remains continuous.
        for analyticsEvent in SubscriptionStatusTransitionAnalytics.trialLifecycleEvents(
            from: previousStatus,
            to: status
        ) {
            analyticsService.track(analyticsEvent.event, properties: analyticsEvent.properties)
        }
    }

    private func loadMonthlyTrialEligibility() async -> Bool {
        guard let subscription = products[PremiumSubscriptionOption.monthly.productIdentifier]?.subscription,
              subscription.introductoryOffer?.paymentMode == .freeTrial else {
            return false
        }

        return await subscription.isEligibleForIntroOffer
    }

    private func isMonthlyFreeTrial(_ transaction: Transaction, option: PremiumSubscriptionOption) -> Bool {
        guard option == .monthly else {
            return false
        }

        if #available(iOS 17.2, *) {
            guard let offer = transaction.offer else {
                return false
            }

            return offer.type == .introductory && offer.paymentMode == .freeTrial
        }

        return transaction.offerType == .introductory
    }

    private func preferredStatus(
        between currentStatus: SubscriptionStatus,
        and candidateStatus: SubscriptionStatus
    ) -> SubscriptionStatus {
        guard candidateStatus.plan >= currentStatus.plan else {
            return currentStatus
        }

        if candidateStatus.plan > currentStatus.plan {
            return candidateStatus
        }

        if candidateStatus.isOnFreeTrial && !currentStatus.isOnFreeTrial {
            return candidateStatus
        }

        let currentDate = currentStatus.trialExpirationDate ?? .distantPast
        let candidateDate = candidateStatus.trialExpirationDate ?? .distantPast
        return candidateDate > currentDate ? candidateStatus : currentStatus
    }
}

/// Actor that serialises concurrent refresh calls.
///
/// If a refresh is already in flight when a new caller arrives, the new caller awaits
/// the in-progress task instead of starting a second redundant network round-trip.
/// Once the task finishes, `self.task` is cleared so the next call starts fresh.
private actor SubscriptionRefreshCoordinator {
    private var task: Task<Void, Never>?

    /// Runs `operation`, coalescing any callers that arrive while it is in progress.
    func run(_ operation: @escaping () async -> Void) async {
        if let task {
            await task.value
            return
        }

        let task = Task {
            await operation()
        }
        self.task = task
        await task.value
        self.task = nil
    }
}
