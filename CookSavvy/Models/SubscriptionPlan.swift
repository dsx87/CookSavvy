//
//  SubscriptionPlan.swift
//  CookSavvy
//

import Foundation

enum SubscriptionPlan: String, CaseIterable, Codable, Comparable {
    case free = "Free"
    case api = "API"
    case ai = "AI"
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .free:
            return "Local database recipes"
        case .api:
            return "Curated recipe API + AI detection"
        case .ai:
            return "AI-generated recipes + AI detection"
        }
    }
    
    var productIdentifier: String? {
        switch self {
        case .free:
            return nil
        case .api:
            return "com.cooksavvy.subscription.api"
        case .ai:
            return "com.cooksavvy.subscription.ai"
        }
    }
    
    private var tier: Int {
        switch self {
        case .free: return 0
        case .api: return 1
        case .ai: return 2
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
    
    var requiredPlans: Set<SubscriptionPlan> {
        switch self {
        case .cameraIngredientDetection:
            return [.api, .ai]
        case .onlineRecipes:
            return [.api, .ai]
        case .aiRecipes:
            return [.ai]
        }
    }
    
    var displayName: String {
        switch self {
        case .cameraIngredientDetection:
            return "Camera Ingredient Detection"
        case .onlineRecipes:
            return "Online Recipes"
        case .aiRecipes:
            return "AI-Generated Recipes"
        }
    }
}
