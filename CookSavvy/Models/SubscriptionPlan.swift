//
//  SubscriptionPlan.swift
//  CookSavvy
//

import Foundation

enum SubscriptionPlan: String, CaseIterable, Codable, Comparable {
    case free = "Free"
    case premium = "Premium"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "CookSavvy+"
        }
    }

    var description: String {
        switch self {
        case .free: return "Basic recipe discovery"
        case .premium: return "Unlimited recipes, camera scanning & smart features"
        }
    }

    var productIdentifier: String? {
        switch self {
        case .free: return nil
        case .premium: return "com.cooksavvy.subscription.premium"
        }
    }


    private var tier: Int {
        switch self {
        case .free: return 0
        case .premium: return 1
        }
    }

    static func < (lhs: SubscriptionPlan, rhs: SubscriptionPlan) -> Bool {
        lhs.tier < rhs.tier
    }
}

enum PaidFeature {
    case cameraIngredientDetection
    case onlineRecipes
    case aiRecipes
    case shoppingList

    var requiredPlans: Set<SubscriptionPlan> {
        return [.premium]
    }

    var displayName: String {
        switch self {
        case .cameraIngredientDetection: return "Camera Scanning"
        case .onlineRecipes: return "Extended Recipes"
        case .aiRecipes: return "AI Recipes"
        case .shoppingList: return "Shopping List"
        }
    }
}
