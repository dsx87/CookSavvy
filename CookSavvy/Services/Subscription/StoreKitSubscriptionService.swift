//
//  StoreKitSubscriptionService.swift
//  CookSavvy
//

import Foundation
import StoreKit
import Combine

// TODO: Review this
@MainActor
final class StoreKitSubscriptionService: SubscriptionServiceProtocol {
    
    @Published private(set) var currentPlan: SubscriptionPlan = .free
    
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> {
        $currentPlan.eraseToAnyPublisher()
    }
    
    private var products: [String: Product] = [:]
    private var transactionListener: Task<Void, Error>?
    
    private let cacheKey = "cached_subscription_plan"
    private let logger: any LoggerProtocol
    
    init(logger: any LoggerProtocol) {
        self.logger = logger
        loadCachedPlan()
        transactionListener = listenForTransactions()
        Task {
            await refreshSubscriptionStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Protocol Methods
    
    func canAccessFeature(_ feature: PaidFeature) -> Bool {
        feature.requiredPlans.contains(currentPlan)
    }
    
    func refreshSubscriptionStatus() async {
        await loadProducts()
        await updateSubscriptionStatus()
    }
    
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
    
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

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
    
    private func updateSubscriptionStatus() async {
        var highestPlan: SubscriptionPlan = .free
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if let plan = planForProductId(transaction.productID), plan > highestPlan {
                highestPlan = plan
            }
        }
        
        currentPlan = highestPlan
        cachePlan(highestPlan)
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.updateSubscriptionStatus()
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let item):
            return item
        case .unverified:
            throw SubscriptionError.verificationFailed
        }
    }
    
    private func planForProductId(_ productId: String) -> SubscriptionPlan? {
        SubscriptionPlan.allCases.first { $0.productIdentifier == productId }
    }
    
    // MARK: - Local Caching
    
    private func loadCachedPlan() {
        if let rawValue = UserDefaults.standard.string(forKey: cacheKey),
           let plan = SubscriptionPlan(rawValue: rawValue) {
            currentPlan = plan
        }
    }
    
    private func cachePlan(_ plan: SubscriptionPlan) {
        UserDefaults.standard.set(plan.rawValue, forKey: cacheKey)
    }
}
