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

