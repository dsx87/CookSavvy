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

    /// Backing subject for the reactive plan publisher.
    private let _currentPlan = CurrentValueSubject<SubscriptionPlan, Never>(.free)

    /// Serialises concurrent refresh calls so only one refresh runs at a time.
    private let refreshCoordinator = SubscriptionRefreshCoordinator()

    /// The user's currently active subscription plan.
    var currentPlan: SubscriptionPlan { _currentPlan.value }

    /// Emits the plan on every change, backed by `_currentPlan`.
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> {
        _currentPlan.eraseToAnyPublisher()
    }
    
    /// Loaded StoreKit products keyed by product identifier.
    private var products: [String: Product] = [:]

    /// Handle to the long-lived transaction-listener task; cancelled on deinit.
    private var transactionListener: Task<Void, Error>?
    
    /// UserDefaults key for the persisted plan raw value.
    private let cacheKey = "cached_subscription_plan"
    private let logger: any LoggerProtocol
    
    /// Initialises the service, loads the cached plan, and begins listening for StoreKit updates.
    /// - Parameter logger: A scoped logger for error reporting.
    init(logger: any LoggerProtocol) {
        self.logger = logger
        loadCachedPlan()
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
    
    /// Purchases a plan through StoreKit 2, finishing the resulting transaction on success.
    ///
    /// Pending transactions (e.g. Ask to Buy) are silently accepted; they will resolve
    /// via the `Transaction.updates` listener when approved.
    /// - Parameter plan: The plan to purchase.
    /// - Throws: `SubscriptionError` for missing products, purchase failures, or user cancellation.
    func purchase(_ plan: SubscriptionPlan) async throws {
        guard let productId = plan.productIdentifier,
              let product = products[productId] else {
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
    
    /// Syncs with the App Store via `AppStore.sync()` and refreshes entitlements.
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    /// Returns the localized display price for the given plan.
    ///
    /// Triggers a product load if the product hasn't been fetched yet.
    func price(for plan: SubscriptionPlan) async -> String? {
        guard let productId = plan.productIdentifier else {
            return nil
        }

        if products[productId] == nil {
            await loadProducts()
        }

        return products[productId]?.displayPrice
    }
    
    // MARK: - Private Methods
    
    /// Fetches all subscription products from the App Store and caches them in `products`.
    private func loadProducts() async {
        let productIds = SubscriptionPlan.allCases.compactMap { $0.productIdentifier }
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
    
    /// Iterates `Transaction.currentEntitlements` to determine the user's highest active plan.
    ///
    /// Only verified transactions are considered. The resolved plan is broadcast via
    /// `_currentPlan` and persisted to UserDefaults for fast startup on the next launch.
    private func updateSubscriptionStatus() async {
        var highestPlan: SubscriptionPlan = .free
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if let plan = planForProductId(transaction.productID), plan > highestPlan {
                highestPlan = plan
            }
        }
        
        _currentPlan.send(highestPlan)
        cachePlan(highestPlan)
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
    
    /// Returns the `SubscriptionPlan` whose product identifier matches the given string.
    private func planForProductId(_ productId: String) -> SubscriptionPlan? {
        SubscriptionPlan.allCases.first { $0.productIdentifier == productId }
    }
    
    // MARK: - Local Caching
    
    /// Reads the persisted plan from UserDefaults and pre-populates `_currentPlan` to avoid
    /// a flash of "free" state while the async refresh is in flight.
    private func loadCachedPlan() {
        if let rawValue = UserDefaults.standard.string(forKey: cacheKey),
           let plan = SubscriptionPlan(rawValue: rawValue) {
            _currentPlan.send(plan)
        }
    }
    
    /// Persists the resolved plan to UserDefaults so it survives app restarts.
    private func cachePlan(_ plan: SubscriptionPlan) {
        UserDefaults.standard.set(plan.rawValue, forKey: cacheKey)
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
