//
//  SubscriptionServiceProtocol.swift
//  CookSavvy
//

import Foundation
import Combine

@MainActor
protocol SubscriptionServiceProtocol: AnyObject {
    var currentPlan: SubscriptionPlan { get }
    var currentPlanPublisher: AnyPublisher<SubscriptionPlan, Never> { get }
    
    func canAccessFeature(_ feature: PaidFeature) -> Bool
    func refreshSubscriptionStatus() async
    func purchase(_ plan: SubscriptionPlan) async throws
    func restorePurchases() async throws
    func price(for plan: SubscriptionPlan) async -> String?
}

enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    case purchaseFailed(Error)
    case verificationFailed
    case userCancelled
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
