//
//  IngredientDetectionService.swift
//  CookSavvy
//

import UIKit

/// Abstracts image-based ingredient detection so the camera flow can be tested without a live AI call.
///
/// The sole production implementation is `AIIngredientDetectionAdapter`, which bridges this
/// protocol to `AIServiceProtocol`. Test and preview builds can substitute a mock conformer.
protocol IngredientDetectionServiceProtocol {
    /// Analyses `image` and returns the ingredients identified within it.
    /// - Parameter image: The captured or selected photo to analyse.
    /// - Returns: Array of detected `Ingredient` values; never empty on success.
    /// - Throws: `IngredientDetectionError` if detection fails or no ingredients are found.
    func detectIngredients(in image: UIImage) async throws -> [Ingredient]
}

/// Errors thrown by `IngredientDetectionServiceProtocol` implementations.
enum IngredientDetectionError: Error, LocalizedError {
    /// The AI model returned a response but could not identify any ingredients in the image.
    case noIngredientsDetected
    /// A downstream error (e.g. network or AI service failure) prevented detection.
    case processingFailed(Error)
    /// The provided `UIImage` could not be converted to a format the AI service accepts.
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

