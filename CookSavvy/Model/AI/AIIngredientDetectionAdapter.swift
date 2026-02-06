//
//  AIIngredientDetectionAdapter.swift
//  CookSavvy
//

import UIKit

final class AIIngredientDetectionAdapter: IngredientDetectionServiceProtocol {
    
    private let aiService: AIServiceProtocol
    
    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }
    
    func detectIngredients(in image: UIImage) async throws -> [Ingredient] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw IngredientDetectionError.invalidImage
        }
        do {
            return try await aiService.detectIngredients(from: imageData)
        } catch let error as AIServiceError {
            switch error {
            case .noIngredientsDetected:
                throw IngredientDetectionError.noIngredientsDetected
            case .invalidImageData:
                throw IngredientDetectionError.invalidImage
            default:
                throw IngredientDetectionError.processingFailed(error)
            }
        }
    }
}
