//
//  IngredientDetectionService.swift
//  CookSavvy
//

import UIKit

protocol IngredientDetectionServiceProtocol {
    func detectIngredients(in image: UIImage) async throws -> [Ingredient]
}

enum IngredientDetectionError: Error, LocalizedError {
    case noIngredientsDetected
    case processingFailed(Error)
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .noIngredientsDetected:
            return "No ingredients detected in the image"
        case .processingFailed(let error):
            return "Failed to process image: \(error.localizedDescription)"
        case .invalidImage:
            return "Invalid image provided"
        }
    }
}

final class MockIngredientDetectionService: IngredientDetectionServiceProtocol {
    
    private let simulatedDelay: TimeInterval
    private let shouldSucceed: Bool
    private let mockIngredients: [Ingredient]
    
    init(
        simulatedDelay: TimeInterval = 2.0,
        shouldSucceed: Bool = true,
        mockIngredients: [Ingredient]? = nil
    ) {
        self.simulatedDelay = simulatedDelay
        self.shouldSucceed = shouldSucceed
        self.mockIngredients = mockIngredients ?? [
            Ingredient(name: "Tomato"),
            Ingredient(name: "Onion"),
            Ingredient(name: "Garlic")
        ]
    }
    
    func detectIngredients(in image: UIImage) async throws -> [Ingredient] {
        try await Task.sleep(nanoseconds: UInt64(simulatedDelay * TimeInterval(NSEC_PER_SEC)))
        
        guard shouldSucceed else {
            throw IngredientDetectionError.processingFailed(
                NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
            )
        }
        
        return mockIngredients
    }
}
